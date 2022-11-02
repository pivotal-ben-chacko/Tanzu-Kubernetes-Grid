## TLS (SSL, x.509) Certificate Generator

`tls-gen` is an OpenSSL-based tool that generates self-signed x.509 certificates that are
meant to be used in development and QA environments.

The project is originally extracted from a number of [RabbitMQ](https://rabbitmq.com) test suites.


## What It Does

`tls-gen` generates a self-signed Certificate Authority (CA) certificate
and two or more pairs of keys: client and server, all with a single command.

It supports more than one profile that generates certificate chains of different length and "shape".

Private keys can be generated using RSA as well as [ECC][ecc-intro].

## Prerequisites

`tls-gen` requires

 * `openssl`
 * Python 3.6 or later in `PATH` as `python3` (older versions are not supported)
 * `make`
 * `hostname`



## Usage

Certificate authorities (CAs) and certificates can form chains. tls-gen provides
several "profiles" that produce different kinds of certificate chains:

 * [Profile 1](./basic/): a root CA with leaf certificate/key pairs signed by it
 * [Profile 2](./two_shared_intermediates/): a root CA with multiple shared intermediary certificates and leaf pairs signed by the intermediaries
 * [Profile 3](./separate_intermediates/): a root CA with two intermediary certificates (one for server, one for client) and leaf pairs signed by the intermediaries

Each profile has a sub-directory in repository root. All profiles use
the same `make` targets and directory layouts that are as close as possible.

### Profile 1 (Basic Profile)

To generate a CA, client and server private key/certificate pairs, run
`make` from the [basic](./basic) profile directory with the `PASSWORD` variable
providing the passphrase:

``` shell
cd [path to tls-gen repository]/basic
# pass a private key password using the PASSWORD variable if needed
make

## copy or move files to use hostname-neutral filenames
## such as client_certificate.pem and client_key.pem,
## this step is optional
# make alias-leaf-artifacts

# results will be under the ./result directory
ls -lha ./result
```

Generated CA certificate as well as client and server certificate and private keys will be
under the `result` directory. Their names will include hostnames. To use
"host-neutral" names such as `client_certificate.pem` and `client_key.pem`, use

``` shell
make alias-leaf-artifacts
```

It is possible to use [ECC][ecc-intro] for leaf keys:

``` shell
cd [path to tls-gen repository]/basic
# pass a private key password using the PASSWORD variable if needed
make USE_ECC=true ECC_CURVE="prime256v1"
# results will be under the ./result directory
ls -lha ./result
```

The list of available curves can be obtained with

``` shell
openssl ecparam -list_curves
```

### Profile 2 (Shared Chained Certificates)

To generate a root CA, 2 shared intermediate CAs, client and server key/certificate pairs, run `make` from
the [two_shared_intermediates](./two_shared_intermediates) directory:

``` shell
# pass a private key password using the PASSWORD variable if needed
make
# results will be under the ./result directory
ls -lha ./result
```

It is possible to use [ECC][ecc-intro] for intermediate and leaf keys:

``` shell
make USE_ECC=true ECC_CURVE="prime256v1"
# results will be under the ./result directory
ls -lha ./result
```

The list of available curves can be obtained with

``` shell
openssl ecparam -list_curves
```

### Profile 3 (Separate Certificate Chains)

To generate a root CA, 2 intermediate CAs (one for server, one for client), client and server key/certificate pairs, run `make` from
the [separate_intermediates](./separate_intermediates) directory:

``` shell
# pass a private key password using the PASSWORD variable if needed
make
# results will be under the ./result directory
ls -lha ./result
```

It is possible to use [ECC][ecc-intro] for intermediate and leaf keys:

``` shell
make USE_ECC=true ECC_CURVE="prime256v1"
# results will be under the ./result directory
ls -lha ./result
```

The list of available curves can be obtained with

``` shell
openssl ecparam -list_curves
```

### Regeneration

To generate a new set of keys and certificates, use

``` shell
# pass a private key password using the PASSWORD variable if needed
make regen
```

The `regen` target accepts the same variables as `gen` (default target) above.

### Verification

You can verify the generated client and server certificates against the generated CA one with

``` shell
make verify
```

### Overriding CN (Common Name)

By default, certificate's CN ([Common Name](http://tldp.org/HOWTO/Apache-WebDAV-LDAP-HOWTO/glossary.html)) is calculated using `hostname`.

It is possible to override CN with a `make` variable:

``` shell
make CN=secure.mydomain.local
```

### Overriding Certificate Validity Period

By default certificates will be valid for 3650 days (about 10 years). The period
can be changed by overriding the `DAYS_OF_VALIDITY` variable

``` shell
make DAYS_OF_VALIDITY=365
```

### Generating Expired Certificates

It may be necessary to generate an expired certificate, e.g. to test TLS handshake
and peer verification failures. To do so, set the certificate validity in
days to a negative value:

``` shell
make DAYS_OF_VALIDITY=-7
```

### Overriding Number of Private Key Bits

It is possible to override the number of private key bits
with a `make` variable:

``` shell
make NUMBER_OF_PRIVATE_KEY_BITS=4096
```

### Certificate Information

To display information about generated certificates, use

``` shell
make info
```

This assumes the certificates were previously generated.



## License

Mozilla Public License, see `LICENSE`.

[ecc-intro]: https://blog.cloudflare.com/a-relatively-easy-to-understand-primer-on-elliptic-curve-cryptography/
