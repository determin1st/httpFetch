<?php
use Mdanter\Ecc\EccFactory;
use Mdanter\Ecc\Primitives\GeneratorPoint;
use Mdanter\Ecc\Serializer\PrivateKey\PemPrivateKeySerializer;
use Mdanter\Ecc\Serializer\PrivateKey\DerPrivateKeySerializer;
use Mdanter\Ecc\Serializer\PublicKey\DerPublicKeySerializer;
use Mdanter\Ecc\Serializer\PublicKey\PemPublicKeySerializer;
use Mdanter\Ecc\Util\NumberSize;
###
class HttpCrypto {
  ###
  private static $me = null, $secret = null, $options = null;
  private $keyPrivate, $keyPublic, $keySecret;
  private $counter = null;
  public $error = '';
  public $isEncrypted = false;
  ###
  # singleton constructor pattern
  public static function setOptions(&$secret, $o = []) # {{{
  {
    # set storage reference
    self::$secret = &$secret;
    # prepare defaults
    if (self::$options === null)
    {
      self::$options = [
        'keyDirectory'   => __DIR__.DIRECTORY_SEPARATOR.'keys',
        'keyFilePrivate' => 'private.pem',
        'keyFilePublic'  => 'public.pem',
        'outputError'    => true,
        'headerName'     => 'HTTP_CONTENT_ENCODING',
      ];
    }
    # apply parameter
    foreach ($o as $k => $v) {
      if (array_key_exists($k, self::$options)) {
        self::$options[$k] = $v;
      }
    }
  }
  # }}}
  public static function getInstance() # {{{
  {
    # check options
    if (self::$options === null) {
      return null;
    }
    # construct once
    if (self::$me === null) {
      self::$me = new HttpCrypto();
    }
    # done
    return self::$me;
  }
  # }}}
  private function __construct() # {{{
  {
    # check requirements(?)
    # ...
    # initialize
    $o = self::$options;
    if (!file_exists($o['keyDirectory']))
    {
      $this->error = 'directory "'.$o['keyDirectory'].'" not found';
      return;
    }
    $a = $o['keyDirectory'].DIRECTORY_SEPARATOR.$o['keyFilePrivate'];
    $b = $o['keyDirectory'].DIRECTORY_SEPARATOR.$o['keyFilePublic'];
    if (!file_exists($a))
    {
      $this->error = 'file "'.$a.'" not found';
      return;
    }
    if (!file_exists($b))
    {
      $this->error = 'file "'.$b.'" not found';
      return;
    }
    $this->keyPrivate = $a;
    $this->keyPublic  = $b;
    # set secret key
    if (empty(self::$secret) || strlen(self::$secret) !== 88) {
      # no secret
      $this->keySecret = null;
    }
    else {
      # convert string to binary data
      $this->keySecret = hex2bin(self::$secret);
    }
    # check specific request header
    $a = $o['headerName'];
    $b = 'aes256gcm';
    if (array_key_exists($a, $_SERVER) && strpos($_SERVER[$a], $b) === 0)
    {
      # request data is encrypted!
      # set flag
      $this->isEncrypted = true;
      # set counter
      if (($a = substr($_SERVER[$a], strlen($b))) !== false && !empty($a)) {
        $this->counter = strval($a);
      }
    }
  }
  # }}}
  ###
  # Diffie-Hellman key exchange
  public function handshake() # {{{
  {
    try
    {
      # clear output buffers
      if (ob_get_level() !== 0) {
        ob_end_clean();
      }
      # check headers
      if (headers_sent()) {
        throw new Exception('headers already sent');
      }
      # check request's content-type and content-encoding
      if (!array_key_exists('CONTENT_TYPE', $_SERVER)) {
        throw new Exception('content-type is not specified');
      }
      if (strpos(strtolower($_SERVER['CONTENT_TYPE']), 'application/octet-stream') !== 0) {
        throw new Exception('incorrect content-type');
      }
      if (!array_key_exists('HTTP_CONTENT_ENCODING', $_SERVER)) {
        throw new Exception('content-encoding is not specified');
      }
      # determine handshake stage
      switch (strtolower($_SERVER['HTTP_CONTENT_ENCODING'])) {
      case 'exchange':
        $a = true;
        break;
      case 'verify':
        $a = false;
        break;
      default:
        throw new Exception('incorrect content-encoding');
      }
      # get request data
      if (($data = file_get_contents('php://input')) === false) {
        throw new Exception('failed to read request data');
      }
      # handle request
      if ($a)
      {
        # EXCHANGE
        # create shared secret and get own public key
        $result = $this->newSharedSecret($data);
      }
      else
      {
        # VERIFY
        # check secret exists
        if ($this->keySecret === null) {
          throw new Exception('secret not found');
        }
        # decrypt message and
        # calculate confirmation hash
        if (($a = $this->decrypt($data)) === false)
        {
          # decryption failed..
          $this->error = 'handshake verification failed';
          # no error thrown and empty response will be treated as positive,
          # that's how handshake attempt may be repeated
          $result = '';
        }
        else if (($result = openssl_digest($a, 'SHA512', true)) === false) {
          throw new Exception('hash-function failed');
        }
      }
    }
    catch (Exception $e)
    {
      $result = null;
      $this->error = $e->getMessage();
    }
    # send negative response
    if ($result === null)
    {
      if (self::$options['outputError'])
      {
        header('content-type: text/plain');
        echo $this->error; flush();
      }
      return false;
    }
    # send positive response
    header('content-type: application/octet-stream');
    echo $result; flush();
    return true;
  }
  # }}}
  private function newSharedSecret($remotePublicKey) # {{{
  {
    # load server keys
    if (($keyPrivate = file_get_contents($this->keyPrivate)) === false) {
      throw new Exception('failed to read private key');
    }
    if (($keyPublic = file_get_contents($this->keyPublic)) === false) {
      throw new Exception('failed to read public key');
    }
    # initialize PHPECC serializers
    # ECDSA domain is defined by curve/generator/hash algorithm
    $adapter   = EccFactory::getAdapter();
    $generator = EccFactory::getNistCurves()->generator384();
    $derPub    = new DerPublicKeySerializer();
    $pemPub    = new PemPublicKeySerializer($derPub);
    $pemPriv   = new PemPrivateKeySerializer(new DerPrivateKeySerializer($adapter, $derPub));
    # parse all
    $keyPrivate = $pemPriv->parse($keyPrivate);
    $keyPublic  = $pemPub->parse($keyPublic);
    $keyRemote  = $derPub->parse($remotePublicKey);
    # create shared secret (using own private and remote public)
    $exchange = $keyPrivate->createExchange($keyRemote);
    $secret = $exchange->calculateSharedKey();
    # truncate secret to 256+96bits for aes128gcm encryption
    $secret = gmp_export($secret);
    $secret = substr($secret, 0, 32+12);# key + iv/counter
    # store secret
    self::$secret = bin2hex($secret);
    # complete with public key
    return $derPub->serialize($keyPublic);
  }
  # }}}
  ###
  # AES GCM encryption/decryption
  public function decryptRequest() # {{{
  {
    # check flag
    if (!$this->isEncrypted) {
      return null;
    }
    # get content type
    $type = isset($_SERVER['CONTENT_TYPE']) ? strtolower($_SERVER['CONTENT_TYPE']) : '';
    $json = false;
    # check it and
    # get encrypted data
    switch (0) {
    case strpos($type, 'application/json'):
      $json = true;
    case strpos($type, 'application/octet-stream'):
    case strpos($type, 'text/plain'):
      # JSON or RAW or TEXT
      $data = file_get_contents('php://input');
      break;
    case strpos($type, 'application/x-www-form-urlencoded'):
    case strpos($type, 'multipart/form-data'):
      # JSON in FormData
      if (!array_key_exists('json', $_REQUEST)) {
        return null;
      }
      $data = $_REQUEST['json'];
      $json = true;
      break;
    default:
      # UNSUPPORTED
      return null;
    }
    # check empty
    if (empty($data)) {
      return [];
    }
    # get etag and modify counter
    if (array_key_exists('HTTP_ETAG', $_SERVER))
    {
    }
    # decrypt
    # ...
    # decode json to array
    return $json ? json_decode($data, true) : $data;
  }
  # }}}
  public function encryptResponse($data) # {{{
  {
    $result = null;
    try
    {
      # check secret exists
      if ($this->keySecret === null) {
        throw new Exception('secret not found');
      }
      # check parameter
      if (!is_string($data)) {
        throw new Exception('incorrect parameter type');
      }
      if (empty($data)) {
        $result = '';
      }
      else
      {
      }
    }
    catch (Exception $e) {
      $this->error = $e->getMessage();
    }
    return $result;
  }
  # }}}
  private function decrypt($data) # {{{
  {
    # extract key and iv
    $key = substr($this->keySecret,  0, 32);
    $iv  = substr($this->keySecret, 32, 12);
    # extract signature (which is included with data)
    $tag  = substr($data, -16);
    $data = substr($data, 0, strlen($data) - 16);
    # decrypt aes256gcm binary data
    return @openssl_decrypt($data, 'aes-256-gcm', $key,
                            OPENSSL_RAW_DATA, $iv, $tag);
  }
  # }}}
  function crypto_encrypt($data, $secret) # {{{
  {
    # prepare data
    # extract key and iv
    $key = substr($secret,  0, 32);
    $iv  = substr($secret, 32, 12);
    $tag = '';
    # encrypt aes256gcm binary data
    $enc = openssl_encrypt($data, 'aes-256-gcm', $key,
                          OPENSSL_RAW_DATA, $iv, $tag);
    # check
    if ($enc === false) {
      return false;
    }
    # append signature
    return $enc.$tag;
  }
  # }}}
  function crypto_next_iv($iv) # {{{
  {
    # change iv/counter
    # split it into two parts and increase both
    $c1 = gmp_add(gmp_import(substr($iv, 0,  6)), '1');
    $c2 = gmp_add(gmp_import(substr($iv, 6, 12)), '1');
    # convert back to binary string
    $c1 = gmp_export($c1);
    $c2 = gmp_export($c2);
    # correct lengths (truncate or pad with zeroes)
    $iv = [$c1, $c2];
    foreach ($iv as $i => $v) {
      if (($a = strlen($v)) !== 6)
      {
        if ($a > 6) {
          $a = 6;
        }
        else if ($a < 6) {
          $a = 6 - $a;
        }
        while ($a > 0)
        {
          $v = chr(0x00).$v;
          $a = $a - 1;
        }
      }
      $iv[$i] = $v;
    }
    # concatenate
    return implode('', $iv);
  }
  # }}}
}
?>
