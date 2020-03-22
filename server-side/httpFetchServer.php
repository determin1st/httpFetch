<?php
use Mdanter\Ecc\EccFactory;
use Mdanter\Ecc\Primitives\GeneratorPoint;
use Mdanter\Ecc\Serializer\PrivateKey\PemPrivateKeySerializer;
use Mdanter\Ecc\Serializer\PrivateKey\DerPrivateKeySerializer;
use Mdanter\Ecc\Serializer\PublicKey\DerPublicKeySerializer;
use Mdanter\Ecc\Serializer\PublicKey\PemPublicKeySerializer;
use Mdanter\Ecc\Util\NumberSize;
###
class HttpFetch {
  ###
  # Base
  # data {{{
  private static
    $me      = null,
    $secret  = null,
    $options = null;
  private
    $keyPrivate, $keyPublic, $keySecret, $counter = null;
  public
    $error     = '',
    $loaded    = false,
    $encrypted = false,
    $rotten    = false;
  # }}}
  public static function setOptions(&$secret, $o = []) # {{{
  {
    # set storage reference
    self::$secret = &$secret;
    # prepare defaults
    if (self::$options === null)
    {
      self::$options = [
        'baseUrl'        => '',
        'uploadDir'      => __DIR__.DIRECTORY_SEPARATOR.'upload',
        'keyDirectory'   => __DIR__.DIRECTORY_SEPARATOR.'keys',
        'keyFilePrivate' => 'private.pem',
        'keyFilePublic'  => 'public.pem',
        'outputError'    => true,
        'testsEnabled'   => true,
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
      self::$me = new HttpFetch();
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
  # Request/Response
  public function load($route) # {{{
  {
    $R = null;
    try
    {
      # check if already loaded
      if ($this->loaded) {
        throw new Exception('already loaded');
      }
      # get request data
      $R = $this->parseRequest();
      # handle internal route
      $this->loaded = $this->routeRequest($route, $R);
    }
    catch (Exception $e)
    {
      # set loaded error
      $this->loaded = true;
      $this->error  = $e->getMessage();
      # report it
      if (self::$options['outputError'])
      {
        header('content-type: text/plain');
        echo $this->error;
      }
      # discard parsed request
      $R = null;
    }
    return $R;
  }
  # }}}
  private function parseRequest() # {{{
  {
    # prepare
    $a = isset($_SERVER['CONTENT_TYPE']) ?
      strtolower($_SERVER['CONTENT_TYPE']) : '';
    # check
    if (strpos($a, 'application/json') === 0)
    {
      # JSON
      # extract data
      if (($a = file_get_contents('php://input')) === null) {
        return null;
      }
      # decrypt it
      if ($this->encrypted && ($a = $this->decryptRequest($a)) === null) {
        throw new Exception('failed to decrypt');
      }
      # decode
      if (($a = json_decode($a, true)) === null &&
          ($b = json_last_error()) !== JSON_ERROR_NONE)
      {
        throw new Exception('incorrect JSON: '.json_last_error_msg());
      }
      # done
      return $a;
    }
    if (strpos($a, 'multipart/form-data') === 0 ||
        strpos($a, 'application/x-www-form-urlencoded') === 0)
    {
      # FormData
      # check encrypted
      if (!$this->encrypted) {
        return $_POST;
      }
      # check wrapped
      if (!array_key_exists('json', $_POST)) {
        return null;
      }
      # decrypt it
      if (($a = $this->decryptRequest($_POST['json'])) === null) {
        throw new Exception('failed to decrypt');
      }
      # decode
      if (($a = json_decode($a, true)) === null &&
          ($b = json_last_error()) !== JSON_ERROR_NONE)
      {
        throw new Exception('incorrect JSON: '.json_last_error_msg());
      }
      # done
      return $a;
    }
    if (strpos($a, 'application/octet-stream') === 0 ||
        strpos($a, 'text/plain') === 0)
    {
      # RAW
      # extract data
      if (($a = file_get_contents('php://input')) === null) {
        return null;
      }
      # check encrypted
      if (!$this->encrypted) {
        return $a;
      }
      # decrypt it
      if (($a = $this->decryptRequest($a)) === null) {
        throw new Exception('failed to decrypt');
      }
      # done
      return $a;
    }
    # EMPTY
    return null;
  }
  # }}}
  private function routeRequest($route, $request) # {{{
  {
    # get base url
    if (($baseUrl = self::$options['baseUrl']) === '') {
      return false;
    }
    # get current path
    $path = explode('/', $route);
    if (count($path) === 0) {
      return false;
    }
    # check entry point
    $a = explode('/', trim($baseUrl, '/'));
    $b = count($a);
    # match last element of the base
    # against first element of the path
    if ($a[$b - 1] !== $path[0]) {
      return false;
    }
    # truncate entry from the path
    $path = array_slice($path, 1);
    # fill in empty extra parameters
    $a = count($path) - 1;
    while (++$a < 3) {
      $path[$a] = '';
    }
    # set CORS headers: allow from anywhere
    $a = array_key_exists('HTTP_ORIGIN', $_SERVER) ?
      $_SERVER['HTTP_ORIGIN'] : '*';
    header('access-control-allow-origin: '.$a);
    header('access-control-allow-credentials: true');
    header('access-control-allow-headers: *, content-type, content-encoding, etag');
    header('access-control-expose-headers: *, content-encoding, location');
    # consider JSON output by default
    $json = null;
    # for encrypted response,
    # activate output buffering
    if ($this->encrypted) {
      ob_start();
    }
    # check
    switch ($path[0]) {
    case 'handshake':
      # shared secret negotiation {{{
      $this->handshake();
      break;
      # }}}
    case 'tests':
      # all tests {{{
      # check available
      if (!self::$options['testsEnabled']) {
        throw new Exception('tests are disabled');
      }
      $testDir = __DIR__.DIRECTORY_SEPARATOR.$path[0];
      if (!file_exists($testDir)) {
        throw new Exception('directory not found: '.$testDir);
      }
      $testDir = $testDir.DIRECTORY_SEPARATOR;
      # proceed
      switch ($path[1]) {
      case 'sleep':
        # {{{
        if (($a = intval($path[2])) <= 0 || $a > 20) {
          $a = 10;
        }
        sleep($a);
        $R = 'successfully slept for '.$a.' seconds';
        break;
        # }}}
      case 'json':
        # {{{
        # raw JSON output
        header('content-type: application/json');
        switch ($path[2]) {
        case 'text':
          echo 'THIS IS A TEXT';
          break;
        case 'null':
          echo 'null';
          break;
        case 'empty':
          break;
        case 'empty_string':
          echo '""';
          break;
        case 'incorrect':
          echo '{something: false}';
          break;
        case 'withBOM':
          echo chr(0xEF).chr(0xBB).chr(0xBF).'true';
          break;
        default:
          echo '{"something": true}';
          break;
        }
        break;
        # }}}
      case 'status':
        # {{{
        # check number range
        if (($a = intval($path[2])) < 100 || $a >= 600) {
          break;
        }
        # echo
        if (is_string($request)) {
          echo $request;
        }
        # set HTTP STATUS
        http_response_code($a);
        break;
        # }}}
      case 'echo':
        # {{{
        # plaintext content
        header('content-type: text/plain');
        # check
        if (($a = $path[2]) === 'crypto' && !$this->encrypted) {
          echo 'access denied';
        }
        if ($request === null) {
          break;
        }
        # send marker
        echo 'echo: ';
        # send content
        if (is_string($request))
        {
          # modify unencrypted plaintext
          if (!$this->encrypted &&
              strpos($request, 'shall pass') !== false)
          {
            $request = str_replace('shall pass', 'shall NOT pass', $request);
          }
          # respond
          echo $request;
        }
        else
        {
          # respond detailed
          var_export($request);
        }
        break;
        # }}}
      case 'upload':
        # {{{
        # prepare
        break;
        if (!isset($path[1]) || !($a = trim(strval($path[1])))) {
          break;
        }
        if (!file_exists(self::$options['uploadDir'])) {
          break;
        }
        $file = self::$options['uploadDir'].DIRECTORY_SEPARATOR.'single.jpg';
        $size = file_exists($file) ? filesize($file) : 0;
        # operate
        switch($a) {
        case 'get-single-jpg':
          # set headers
          header('Cache-Control: no-store');
          header('Content-Type: image/jpeg');
          header('Content-Length: '.$size);
          # read file
          if ($size > 0) {
            readfile($file);
          }
          break;
        case 'put-single-jpg':
          # get uploaded file
          /***
          if (!($a = normalizeFiles('image')) || count($a) !== 1) {
            break;
          }
          # check type
          $a = $a[0];
          if ($a['type'] !== 'image/jpeg') {
            break;
          }
          # store image
          if (!move_uploaded_file($a['tmp_name'], $file)) {
            break;
          }
          # return metadata as is
          $result = $request;
          /***/
          break;
        }
        break;
        # }}}
      case 'redirect':
        # {{{
        if (($a = intval($path[2])) > 0)
        {
          $path[2] = $a - 1;
          header('location: '.self::$options['baseUrl'].implode('/', $path));
          http_response_code(307);
        }
        else
        {
          header('content-type: text/plain');
          echo 'redirect complete';
        }
        break;
        # }}}
      case 'redirect-300':
        # {{{
        if (($a = intval($path[2])) > 0)
        {
          $path[2] = $a - 1;
          header('location: '.self::$options['baseUrl'].implode('/', $path));
          http_response_code(300);
        }
        else
        {
          header('content-type: text/plain');
          echo 'redirect complete';
        }
        break;
        # }}}
      case 'redirect-custom':
        # {{{
        if (($a = intval($path[2])) > 0 && $a <= 30)
        {
          # compose route
          $json = '/'.$path[0].'/'.$path[1].'/'.strval($a - 1);
        }
        else if ($a < 0 && $a >= -30)
        {
          # compose random route
          $json = '/'.$path[0].'/'.$path[1].'/-'.strval(rand(0, 30));
        }
        else
        {
          # give final url
          $json = 'https://api.quotable.io/random';
        }
        break;
        # }}}
      case 'download':
        # {{{
        # check
        if ($this->encrypted) {
          break;
        }
        # not encrypted
        # prepare
        switch ($path[2]) {
        case 'img':
          # chunked image {{{
          # get file
          $file = $testDir.'grasp.jpg';
          $size = file_exists($file) ? filesize($file) : 0;
          # set headers
          header('Cache-Control: no-store');
          header('Content-Type: image/jpeg');
          header('Content-Length: '.$size);
          # transfer chunks with delay
          if ($size > 0)
          {
            if (($a = fopen($file, 'r')) === false) {
              throw new Exception('failed to open: '.$file);
            }
            $n = 1 + round($size / 20, 0);
            $i = -1;
            while (++$i < 20)
            {
              # read
              if (($b = fread($a, $n)) === false) {
                throw new Exception('failed to read: '.$file);
              }
              # output
              echo $b; flush();
              # delay
              usleep(100000);# 0.1s
            }
          }
          break;
          # }}}
        default:
          break;
        }
        break;
        # }}}
      default:
        # availability check
        $json = ($path[2] === '');
      }
      break;
      # }}}
    default:
      # version check
      $json = 1;
    }
    # output JSON
    if ($json !== null && ($json = json_encode($json, JSON_UNESCAPED_UNICODE)))
    {
      header('content-type: application/json');
      echo $json;
    }
    # for encrypted response,
    # flush the buffer and encrypt it
    if ($this->encrypted) {
      echo $this->encryptResponse(ob_get_clean());
    }
    return true;
  }
  # }}}
  private function decryptRequest($data) # {{{
  {
    try
    {
      # check secret key
      if ($this->keySecret === null) {
        throw new Exception('no shared secret');
      }
      # check counter
      if ($this->counter === null) {
        throw new Exception('counter is undefined');
      }
      # check data
      if (!is_string($data) || $data === '') {
        throw new Exception('incorrect data');
      }
      ###
      # advance secret's counter
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
    }
    catch (Exception $e)
    {
      $this->encrypted = false;
      $this->error = $e->getMessage();
      $data = null;
    }
    # done
    return $data;
  }
  # }}}
  private function encryptResponse($data) # {{{
  {
    $R = '';
    try
    {
      # check secret key
      if ($this->keySecret === null) {
        throw new Exception('shared secret must be established');
      }
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
      if (($R = $this->encrypt($data)) === null)
      {
        # set empty result
        $R = '';
        throw new Exception('failed to encrypt');
      }
      # successfully encrypted!
      # set encoding
      header('content-encoding: aes256gcm');
      # update secret
      self::$secret = bin2hex($this->keySecret);
    }
    catch (Exception $e) {
      $this->error = $e->getMessage();
    }
    return $R;
  }
  # }}}
  ###
  # Crypto
  # Diffie-Hellman key exchange
  private function handshake() # {{{
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
  ###
  # Helpers
}
?>
