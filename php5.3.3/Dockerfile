FROM alpine:3.3

# Set up the repo and runtime deps
RUN echo "@edge http://nl.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories
RUN apk add -U apache2 curl curl-dev libxml2-dev readline-dev recode-dev@edge

# Set up environment vars
ENV PHP_INI_DIR /usr/local/etc/php
ENV buildDeps "apache2-dev \
	file \
	g++ \
	gcc \
	libc-dev \
	make \
	patch"
ENV PHP_EXTRA_CONFIGURE_ARGS --with-apxs2=/usr/bin/apxs
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
	&& apk add $buildDeps \
	&& curl -L "http://museum.php.net/php5/$PHP_FILENAME" -o "$PHP_FILENAME" \
	&& echo "$PHP_SHA256 *$PHP_FILENAME" | sha256sum -c - \
	&& tar -xjf "$PHP_FILENAME" -C /usr/src/php/ \
	&& rm "$PHP_FILENAME"* \
	&& cd /usr/src/php \
	&& mv php-5.3.3/* . \
	&& rm -rf php-5.3.3 \
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
	&& make \
	&& make install \
	&& make clean \
	&& apk del $buildDeps \
	&& cd \
	&& rm -rf /usr/src/php/

# Set up the PHP timezone
RUN echo "date.timezone=America/Toronto" >> /usr/local/etc/php/php.ini

# Add PHP support to httpd
COPY httpd_php.conf .
RUN cat httpd_php.conf >> /etc/apache2/httpd.conf \
	&& rm httpd_php.conf \
	&& sed -i 's|LoadModule.*libphp5.so|LoadModule php5_module /usr/lib/apache2/libphp5.so|' /etc/apache2/httpd.conf

# Set workdir to the docroot, add our test index page.
WORKDIR /var/www/localhost/htdocs/
ADD index.php .
RUN rm -f index.html

# Create the entrypoint
COPY apache2-foreground /usr/local/bin/

# Set up the needed PID dir
RUN mkdir /run/apache2/

# Expose port, run
EXPOSE 80
CMD ["apache2-foreground"]
