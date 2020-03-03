FROM debian:buster
MAINTAINER Bohm Technologies <it@bohmtech.com>

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG C.UTF-8

# Create the Odoo User and assign it to a specific UID so ODOO has write access to the
# NFS mount points.

RUN mkdir /var/lib/odoo \
    && groupadd odoo -g 1002 \
    && useradd -d /var/lib/odoo -s /bin/false -u 1002 -g odoo odoo \
    && chown -R odoo:odoo /var/lib/odoo

# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf
RUN set -x; \
        apt-get update \
        && apt-get install -y --no-install-recommends \
            vim \
            ca-certificates \
            curl \
            node-less \
            python3-pip \
            python3-setuptools \
            python3-renderpm \
            libssl-dev \
            xz-utils \
            software-properties-common \
            build-essential \
            libffi-dev \
            python3-dev \
            python3-watchdog \
        && curl -o wkhtmltox.tar.xz -SL https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.4/wkhtmltox-0.12.4_linux-generic-amd64.tar.xz \
        && echo '3f923f425d345940089e44c1466f6408b9619562 wkhtmltox.tar.xz' | sha1sum -c - \
        && tar xvf wkhtmltox.tar.xz \
        && cp wkhtmltox/lib/* /usr/local/lib/ \
        && cp wkhtmltox/bin/* /usr/local/bin/ \
        && cp -r wkhtmltox/share/man/man1 /usr/local/share/man/

# Install Odoo
ENV ODOO_VERSION 11.0
ENV ODOO_RELEASE 20181129
RUN set -x; \
        curl -o odoo.deb -SL http://nightly.odoo.com/${ODOO_VERSION}/nightly/deb/odoo_${ODOO_VERSION}.${ODOO_RELEASE}_all.deb \
        && echo '10faa334af9d385983f114e7d5151a4a420f02f5 odoo.deb' | sha1sum -c - \
        && dpkg --force-depends -i odoo.deb \
        && apt-get update \
        && apt-get -y install -f --no-install-recommends \
        && rm -rf /var/lib/apt/lists/* odoo.deb

# Copy entrypoint script and Odoo configuration file
RUN pip3 install wheel
RUN pip3 install qrcode vobject num2words xlwt pyjwt phonenumbers redis gevent pyopenssl sentry-sdk json2html
COPY ./entrypoint.sh /
COPY ./odoo.conf /etc/odoo/
RUN chown odoo /etc/odoo/odoo.conf

# Create the Odoo Enterprise and Session Directories.
RUN mkdir -p /mnt/enterprise && mkdir -p /mnt/session/smile_redis_session_store

# Copy Redis Session
COPY ./smile_redis_session_store/ /mnt/session/smile_redis_session_store/

# Copy Enterprise into the Docker Container
COPY ./enterprise/ /mnt/enterprise/

# Mount /var/lib/odoo to allow restoring filestore and /mnt/extra_addons for users addons
RUN mkdir -p /mnt/extra_addons \
        && chown -R odoo /mnt/extra_addons
VOLUME ["/var/lib/odoo", "/mnt/extra_addons"]

# Expose Odoo services
EXPOSE 8069 8071

# Set the default config file
ENV ODOO_RC /etc/odoo/odoo.conf

# Set default user when running the container
USER odoo

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]
