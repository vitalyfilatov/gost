FROM ubuntu:23.10

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install build-essential wget git cmake unzip gcc python3 python3-pip python3-openssl -y

ARG PREFIX="/usr/local/ssl"

# Build openssl
ARG OPENSSL_VERSION="3.1.4"
RUN cd /usr/local/src \
  && wget --no-check-certificate "https://github.com/openssl/openssl/archive/openssl-${OPENSSL_VERSION}.zip" -O "openssl-${OPENSSL_VERSION}".zip \
  && unzip "openssl-${OPENSSL_VERSION}.zip" -d ./ \
  && cd "openssl-openssl-${OPENSSL_VERSION}" \
  && ./config shared -d --prefix=${PREFIX} --openssldir=${PREFIX} && make -j$(nproc) all && make install \
  && mv /usr/bin/openssl /root/ \
  && ln -s ${PREFIX}/bin/openssl /usr/bin/openssl

# Update path of shared libraries
RUN echo "${PREFIX}/lib" >> /etc/ld.so.conf.d/ssl.conf && ldconfig

ARG ENGINES=${PREFIX}/lib/engines-3

# Build GOST-engine for OpenSSL
ARG GOST_ENGINE_VERSION=2a8a5e0ecaa3e3d6f4ec722a49aa72476755c2b7
RUN cd /usr/local/src \
  && wget --no-check-certificate "https://github.com/gost-engine/engine/archive/${GOST_ENGINE_VERSION}.zip" -O gost-engine.zip \
  && unzip gost-engine.zip -d ./ \
  && cd "engine-${GOST_ENGINE_VERSION}" \
  && git clone https://github.com/provider-corner/libprov.git \
  && mkdir build \
  && cd build \
  && cmake -DCMAKE_BUILD_TYPE=Release -DOPENSSL_ROOT_DIR=${PREFIX} -DOPENSSL_LIBRARIES=${PREFIX}/lib -DOPENSSL_ENGINES_DIR=${ENGINES} -Wno-dev .. \
  && cmake --build . --config Release \
  && cmake --build . --target install --config Release \
  && cd bin \
  && cp gostsum gost12sum /usr/local/bin \
  && cd .. \
  && rm -rf "/usr/local/src/gost-engine.zip" "/usr/local/src/engine-${GOST_ENGINE_VERSION}"

# Enable engine
RUN sed -i -e 's/openssl_conf = openssl_init/openssl_conf = openssl_def/g' ${PREFIX}/openssl.cnf \
  && echo "" >>${PREFIX}/openssl.cnf \
  && echo "# OpenSSL default section" >>${PREFIX}/openssl.cnf \
  && echo "[openssl_def]" >>${PREFIX}/openssl.cnf \
  && echo "engines = engine_section" >>${PREFIX}/openssl.cnf \
  && echo "" >>${PREFIX}/openssl.cnf \
  && echo "# Engine scetion" >>${PREFIX}/openssl.cnf \
  && echo "[engine_section]" >>${PREFIX}/openssl.cnf \
  && echo "gost = gost_section" >>${PREFIX}/openssl.cnf \
  && echo "" >> ${PREFIX}/openssl.cnf \
  && echo "# Engine gost section" >>${PREFIX}/openssl.cnf \
  && echo "[gost_section]" >>${PREFIX}/openssl.cnf \
  && echo "engine_id = gost" >>${PREFIX}/openssl.cnf \
  && echo "dynamic_path = ${ENGINES}/gost.so" >>${PREFIX}/openssl.cnf \
  && echo "default_algorithms = ALL" >>${PREFIX}/openssl.cnf \
  && echo "CRYPT_PARAMS = id-Gost28147-89-CryptoPro-A-ParamSet" >>${PREFIX}/openssl.cnf \
  && mv /etc/ssl/openssl.cnf /etc/ssl/openssl.cnf.orig \
  && ln -s ${PREFIX}/openssl.cnf /etc/ssl/openssl.cnf

# Rebuild curl
#ARG CURL_VERSION=8.4.0
#ARG CURL_SHA256="01ae0c123dee45b01bbaef94c0bc00ed2aec89cb2ee0fd598e0d302a6b5e0a98"
#RUN apt-get remove curl -y \
#  && rm -rf /usr/local/include/curl \
#  && cd /usr/local/src \
#  && wget --no-check-certificate "https://curl.haxx.se/download/curl-${CURL_VERSION}.tar.gz" -O "curl-${CURL_VERSION}.tar.gz" \
#  # && echo "$CURL_SHA256" "curl-${CURL_VERSION}.tar.gz" | sha256sum -c - \
#  && tar -zxvf "curl-${CURL_VERSION}.tar.gz" \
#  && cd "curl-${CURL_VERSION}" \
#  && CPPFLAGS="-I/usr/local/ssl/include" LDFLAGS="-L${PREFIX}/lib -Wl,-rpath,${PREFIX}/lib" LD_LIBRARY_PATH=${PREFIX}/lib \
#   ./configure --prefix=/usr/local/curl --with-ssl=${PREFIX} --with-libssl-prefix=${PREFIX} \
#  && make \
#  && make install \
#  && ln -s /usr/local/curl/bin/curl /usr/bin/curl \
#  && rm -rf "/usr/local/src/curl-${CURL_VERSION}.tar.gz" "/usr/local/src/curl-${CURL_VERSION}" 

# Rebuild stunnel
#ARG STUNNEL_VERSION=5.71
#ARG STUNNEL_SHA256="c45d765b1521861fea9b03b425b9dd7d48b3055128c0aec673bba5ef9b8f787d"
#RUN cd /usr/local/src \
#  && wget --no-check-certificate "https://www.stunnel.org/downloads/stunnel-${STUNNEL_VERSION}.tar.gz" -O "stunnel-${STUNNEL_VERSION}.tar.gz" \
#  # && echo "$STUNNEL_SHA256" "stunnel-${STUNNEL_VERSION}.tar.gz" | sha256sum -c - \
#  && tar -zxvf "stunnel-${STUNNEL_VERSION}.tar.gz" \
#  && cd "stunnel-${STUNNEL_VERSION}" \
#  && CPPFLAGS="-I${PREFIX}/include" LDFLAGS="-L${PREFIX}/lib -Wl,-rpath,${PREFIX}/lib" LD_LIBRARY_PATH=${PREFIX}/lib \
#   ./configure --prefix=/usr/local/stunnel --with-ssl=${PREFIX} \
#  && make \
#  && make install \
#  && ln -s /usr/local/stunnel/bin/stunnel /usr/bin/stunnel \
#  && rm -rf "/usr/local/src/stunnel-${STUNNEL_VERSION}.tar.gz" "/usr/local/src/stunnel-${STUNNEL_VERSION}"

