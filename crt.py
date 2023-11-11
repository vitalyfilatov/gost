from OpenSSL import crypto
cert = crypto.load_certificate(crypto.FILETYPE_PEM, open('gost.crt').read())
cert.get_pubkey()

