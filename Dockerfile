FROM httpd:2.2

# Install persistent reqs
RUN apt-get update && apt-get install -y ca-certificates curl librecode0 libsqlite3-0 libxml2 --no-install-recommends && rm -r /var/lib/apt/lists/*

# Set up environment vars
ENV PHP_INI_DIR /usr/local/etc/php
ENV buildDeps "autoconf \
	file \
	g++ \
	gcc \
	libc-dev \
	make \
	pkg-config \
	re2c \
	libcurl4-openssl-dev \
	libreadline6-dev \
	librecode-dev \
	libsqlite3-dev \
	libssl-dev \
	libxml2-dev \
	libz-dev \
	lbzip2 \
	patch"
ENV PHP_EXTRA_CONFIGURE_ARGS --with-apxs2=/usr/local/apache2/bin/apxs
ENV PHP_VERSION 5.3.3
ENV PHP_FILENAME php-5.3.3.tar.bz2
ENV PHP_SHA256 f2876750f3c54854a20e26a03ca229f2fbf89b8ee6176b9c0586cb9b2f0b3f9a

# Create directories we'll need
RUN mkdir -p $PHP_INI_DIR/conf.d
RUN mkdir -p /usr/src/php

# Copy files needed for compile
COPY libxml.patch /usr/src/php/

# Compile and install
RUN set -x \
	&& apt-get update && apt-get install -y $buildDeps --no-install-recommends \
	&& curl -fSL "http://museum.php.net/php5/$PHP_FILENAME" -o "$PHP_FILENAME" \
	&& echo "$PHP_SHA256 *$PHP_FILENAME" | sha256sum -c - \
	&& tar -xf "$PHP_FILENAME" -C /usr/src/php --strip-components=1 \
	&& rm "$PHP_FILENAME"* \
	&& cd /usr/src/php \
	&& patch -p0 < libxml.patch \
	&& ./configure \
			--with-config-file-path="$PHP_INI_DIR" \
			--with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
			$PHP_EXTRA_CONFIGURE_ARGS \
			--disable-cgi \
			--with-curl \
			--without-openssl \
			--with-readline \
			--with-recode \
			--with-zlib \
			--with-pdo-mysql=mysqlnd \
	&& echo "EXTRA_LIBS += -lcrypto" >> Makefile \
	&& make -j"$(nproc)" \
	&& make install \
	&& { find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true; } \
	&& make clean \
	&& apt-get purge -y --auto-remove \
		-o APT::AutoRemove::RecommendsImportant=false \
		-o APT::AutoRemove::SuggestsImportant=false \
		$buildDeps \
		&& cd \
	&& rm -rf /usr/src/php/

# Set up the PHP timezone
RUN echo "date.timezone=America/Toronto" >> /usr/local/etc/php/php.ini

# Add PHP support to httpd
COPY httpd_php.conf .
RUN cat httpd_php.conf >> /usr/local/apache2/conf/httpd.conf \
	&& rm httpd_php.conf

# Set workdir to the docroot, add our test index page.
WORKDIR /usr/local/apache2/htdocs/
ADD index.php .
RUN rm -f index.html

# Create the entrypoint
COPY apache2-foreground /usr/local/bin/

# Expose port, run
EXPOSE 80
CMD ["apache2-foreground"]
