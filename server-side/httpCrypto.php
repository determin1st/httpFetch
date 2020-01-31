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
  public $encrypted = false;
  public $rotten = false;
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
    if (strlen(self::$secret) !== 88) {
      # no secret
      $this->keySecret = null;
    }
    else {
      # convert string to binary
      $this->keySecret = hex2bin(self::$secret);
    }
    # check specific request headers
    $a = 'HTTP_CONTENT_ENCODING';
    $b = 'HTTP_ETAG';
    if (array_key_exists($a, $_SERVER) && $_SERVER[$a] === 'aes256gcm')
    {
      # request data is encrypted!
      # set flag
      $this->encrypted = true;
      # set counter value
      if (array_key_exists($b, $_SERVER) &&
          strlen($_SERVER[$b]) === 4 &&
          ($a = @hex2bin($_SERVER[$b])) !== false)
      {
        $this->counter = $a;
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
      if (!array_key_exists('HTTP_ETAG', $_SERVER)) {
        throw new Exception('etag is not specified');
      }
      # determine handshake stage
      switch (strtolower($_SERVER['HTTP_ETAG'])) {
      case 'exchange':
        $a = true;
        break;
      case 'verify':
        $a = false;
        break;
      default:
        throw new Exception('incorrect etag');
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
        echo $this->error;
      }
      return false;
    }
    # send positive response
    header('content-type: application/octet-stream');
    echo $result;
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
    $R = null;
    try
    {
      # check flag
      if (!$this->encrypted) {
        throw new Exception('');
      }
      # check secret key
      if ($this->keySecret === null) {
        throw new Exception('shared secret must be established');
      }
      # check counter
      if ($this->counter === null) {
        throw new Exception('counter is not set');
      }
      ###
      # get content type
      $type = isset($_SERVER['CONTENT_TYPE']) ?
        strtolower($_SERVER['CONTENT_TYPE']) : '';
      # determine content type group
      if (strpos($type, 'application/octet-stream') === 0 ||
          strpos($type, 'text/plain') === 0)
      {
        $type = 0;
      }
      else if (strpos($type, 'application/json') === 0) {
        $type = 1;
      }
      else if (strpos($type, 'multipart/form-data') === 0)
      {
        if (!array_key_exists('json', $_REQUEST)) {
          throw new Exception('incorrect request, required parameter key does not exist');
        }
        $type = 2;
      }
      else {
        throw new Exception('given content-type is not supported');
      }
      ###
      # get encrypted data
      $data = ($type === 2) ?
        $_REQUEST['json'] : file_get_contents('php://input');
      # check empty
      if (!is_string($data) || $data === '') {
        throw new Exception('incorrect request, data must not be empty');
      }
      ###
      # determine new secret
      # prepare
      $counterLimit = '1208925819614629174706176';# maximum + 1
      # public part of the counter is set by the client and
      # mirrored by the server to handle AES GCM protocol
      # extract all parts of the counter
      $a = gmp_import(substr($this->keySecret, -12, 10));
      $b = gmp_intval(gmp_import(substr($this->keySecret, -2)));
      $c = gmp_intval(gmp_import($this->counter));
      # check the difference
      if (($d = $c - $b) >= 0)
      {
        # positive value is perfectly fine,
        # the client's counter is ahead of the server's or equals,
        # later assumes repetition of the request.
        # increase!
        $a = gmp_add($a, $d);
      }
      else
      {
        # negative value may fall in two cases:
        # - overflow of the public, smaller counter part,
        #   which is alright, no problemo situation.
        # - previous request/response failure,
        #   which may break further key usage if
        #   the failure collide with counter overflow.
        # determine distances
        xdebug_break();
        $c = 65536 + $c - $b;
        $d = abs($d);
        # check the case optimistically
        if ($c <= $d)
        {
          # increase (overflow)
          $a = gmp_add($a, $c);
        }
        else
        {
          # decrease (failure)
          $a = gmp_sub($a, $d);
          # check bottom overflow (should be super rare)
          if (gmp_sign($a) === -1) {
            $a = gmp_sub($counterLimit, $a);
          }
        }
      }
      # check private counter overflows the upper limit
      if (gmp_cmp($counterLimit, $a) <= 0) {
        $a = gmp_sub($a, $counterLimit);
      }
      # private counter determined!
      # convert it back to string and left-pad with zeros
      $a = str_pad(gmp_export($a), 10, chr(0x00), STR_PAD_LEFT);
      # update secret
      $this->keySecret = substr($this->keySecret, 0, 32).$a.$this->counter;
      ###
      # decrypt data
      if (($data = $this->decrypt($data)) === null)
      {
        # in general, failure means that secret keys mismatch and
        # special measures should take place, for example:
        # - reset user session
        # - delay/block further requests
        # - ...
        # to indicate this state,
        # set the flag and destroy secret
        $this->rotten = true;
        self::$secret = '';
        # fail
        throw new Exception('failed to decrypt');
      }
      # update secret store
      self::$secret = bin2hex($this->keySecret);
      # decode JSON
      if ($type !== 0 && ($data = json_decode($data, true)) === null) {
        throw new Exception('incorrect JSON: '.json_last_error_msg());
      }
      # success
      $R = $data;
    }
    catch (Exception $e)
    {
      $this->encrypted = false;
      $this->error = $e->getMessage();
    }
    # display error
    if (!empty($this->error) && self::$options['outputError'])
    {
      header('content-type: text/plain');
      echo $this->error;
    }
    # done
    return $R;
  }
  # }}}
  public function encryptResponse($data) # {{{
  {
    $result = '';
    try
    {
      # check flag
      if (!$this->encrypted) {
        throw new Exception('');
      }
      # check secret key
      if ($this->keySecret === null) {
        throw new Exception('shared secret must be established');
      }
      ###
      # determine new secret
      # prepare
      $limit1 = '1208925819614629174706176';# maximum + 1
      $limit2 = 65536;
      # extract all parts of the counter
      $a = gmp_import(substr($this->keySecret, -12, 10));
      $b = gmp_intval(gmp_import(substr($this->keySecret, -2)));
      # increase both
      $a = gmp_add($a, '1');
      $b = $b + 1;
      # fix overflows
      if (gmp_cmp($a, $limit1) > 0) {
        $a = gmp_sub($a, $limit1);
      }
      if ($b > 65536) {
        $b = $b - 65536;
      }
      # convert to strings
      $a = str_pad(gmp_export($a), 10, chr(0x00), STR_PAD_LEFT);
      $b = str_pad(gmp_export($b), 2, chr(0x00), STR_PAD_LEFT);
      # update secret
      $this->keySecret = substr($this->keySecret, 0, 32).$a.$b;
      # encrypt data
      if (($result = $this->encrypt($data)) === null)
      {
        # set empty result
        $result = '';
        throw new Exception('failed to encrypt');
      }
      # set encoding
      header('content-encoding: aes256gcm');
      # update secret store
      self::$secret = bin2hex($this->keySecret);
    }
    catch (Exception $e) {
      $this->error = $e->getMessage();
    }
    # display error
    if (!empty($this->error) && self::$options['outputError']) {
      $result = $this->error;
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
    $data = @openssl_decrypt($data, 'aes-256-gcm', $key,
                             OPENSSL_RAW_DATA, $iv, $tag);
    # check
    if ($data === false) {
      return null;
    }
    return $data;
  }
  # }}}
  private function encrypt($data) # {{{
  {
    # extract key and iv
    $key = substr($this->keySecret,  0, 32);
    $iv  = substr($this->keySecret, 32, 12);
    # prepare message tag
    $tag = '';
    # encrypt aes256gcm binary data
    $enc = @openssl_encrypt($data, 'aes-256-gcm', $key,
                            OPENSSL_RAW_DATA, $iv, $tag);
    # check
    if ($enc === false) {
      return null;
    }
    # append signature and
    # complete
    return $enc.$tag;
  }
  # }}}
}
?>
