#!/bin/bash

set -e

STR_KEY=key
STR_CERT=certificate
FILE_CA=ca_certificate.pem 

DIR=rabbitmq-tls

echo "Enter common name (CN) for certificate: "
read var

make PASSWORD=bunnies CN=$var

if [ ! -d "$DIR" ]; then
  mkdir $DIR
fi

cd result 

if [[ -f "$FILE_CA" ]]; then
    echo "Renaming: $FILE_CA to ca.crt"
    cp $FILE_CA ../$DIR/ca.crt
fi


for f in server*.pem; do
  if [[ "$f" == *"$STR_KEY"* ]]; then
    echo "Renaming: $f to tls.key"
    cp $f ../$DIR/tls.key
  elif [[ "$f" == *"$STR_CERT"* ]]; then
    echo "Renaming: $f to tls.crt"
    cp $f ../$DIR/tls.crt
  fi
done

cd ../client*

cp cert.pem ../$DIR/client_certificate.pem
cp key.pem  ../$DIR/client_key.pem
