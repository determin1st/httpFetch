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
  public $error = '';
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
  }
  # }}}
  ###
  # Diffie-Hellman key exchange
  public function handshake() # {{{
  {
    # clear output buffer
    if (ob_get_level() !== 0) {
      ob_end_clean();
    }
    # check headers
    if (headers_sent())
    {
      $this->error = 'headers already sent';
      return false;
    }
    # check request's content-type and content-encoding
    if (!array_key_exists('CONTENT_TYPE', $_SERVER))
    {
      $this->error = 'content-type is not specified';
      return false;
    }
    if (strpos(strtolower($_SERVER['CONTENT_TYPE']), 'application/octet-stream') !== 0)
    {
      $this->error = 'incorrect content-type';
      return false;
    }
    if (!array_key_exists('HTTP_CONTENT_ENCODING', $_SERVER))
    {
      $this->error = 'content-encoding is not specified';
      return false;
    }
    # determine handshake stage
    switch (strtolower($_SERVER['HTTP_CONTENT_ENCODING'])) {
    case '':
      $a = true;
      break;
    case 'aes256gcm':
      $a = false;
      break;
    default:
      $this->error = 'incorrect content-encoding';
      return false;
    }
    # get request data
    if (($data = file_get_contents('php://input')) === false)
    {
      $this->error = 'failed to read request data';
      return false;
    }
    # handle request
    if ($a)
    {
      # EXCHANGE
      # create shared secret and get own public key
      if (($a = $this->newSharedSecret($data)) === null) {
        return false;
      }
    }
    else
    {
      # VERIFY
      # check secret exists
      if ($this->keySecret === null)
      {
        $this->error = 'no shared secret';
        return false;
      }
      # decrypt message and
      # calculate confirmation hash
      if (($a = $this->decrypt($data)) === false)
      {
        # decryption failed..
        $this->error = 'handshake verification failed';
        # the handshake attempt may be repeated
        # set an empty, but positive response!
        $a = '';
      }
      else if (($a = openssl_digest($a, 'SHA512', true)) === false)
      {
        $this->error = 'hash-function failed';
        return false;
      }
    }
    # send the response
    header('content-type: application/octet-stream');
    echo $a; flush();
    # done
    return true;
  }
  # }}}
  private function newSharedSecret($remotePublicKey) # {{{
  {
    # load server keys
    $keyPrivate = file_get_contents($this->keyPrivate);
    $keyPublic  = file_get_contents($this->keyPublic);
    if ($keyPrivate === false || $keyPublic === false)
    {
      $this->error = 'failed to read server keys';
      return null;
    }
    // initialize PHPECC serializers
    // ECDSA domain is defined by curve/generator/hash algorithm
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
    # complete
    return $derPub->serialize($keyPublic);
  }
  # }}}
  ###
  # AES GCM encryption/decryption
  private function decrypt($data) # {{{
  {
    # extract key and iv
    $key = substr($this->keySecret,  0, 32);
    $iv  = substr($this->keySecret, 32, 12);
    # extract signature (which is included with data)
    $tag  = substr($data, -16);
    $data = substr($data, 0, strlen($data) - 16);
    # decrypt aes256gcm binary data
    return openssl_decrypt($data, 'aes-256-gcm', $key,
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
