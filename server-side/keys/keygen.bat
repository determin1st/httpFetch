@echo off
echo.
echo -------------
echo  ECDH keygen
echo -------------
echo.
set K1=private.pem
set K2=public.pem
set OPENSSL=E:\lab\iOne\PutList\xampp\apache\bin\openssl.exe
choice /T 20 /D N /M "Generate a keypair?"
if %ERRORLEVEL% equ 1 goto WORK
goto END

:WORK
%OPENSSL% ecparam -name secp521r1 -genkey -noout -out %K1%
%OPENSSL% ec -in %K1% -pubout -out %K2%
goto END

:END
exit
