ARG NGINX_VERSION=1.26.3
ARG OPENRESTY_VERSION=1.25.3.2
ARG NGINX_RTMP_VERSION=1.2.2-r1
ARG FFMPEG_VERSION=7.1
ARG NV_CODEC_VERSION=n13.0.19.0
ARG LUAJIT_VERSION=2.1-20250117
ARG NGX_VERSION=0.3.3
ARG LUA_NGINX_VERSION=0.10.28

##############################
# Build the NGINX-build image.
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04 as build-nginx
ARG NGINX_VERSION
ARG OPENRESTY_VERSION
ARG NGINX_RTMP_VERSION
ARG LUAJIT_VERSION
ARG NGX_VERSION
ARG LUA_NGINX_VERSION

# Build dependencies.
RUN apt update && apt install -y \
  ca-certificates \
  curl \
  gcc \
  libc-dev \
  make \
  libssl-dev \
  libpcre3 \
  libpcre3-dev \
  #linux-headers-$(uname -r) \
#  linux-headers \
# luajit \
  pkg-config \
  wget \
  zlib1g-dev

# Build linux-headers from source
RUN apt update && apt install -y \
  build-essential \
  bison \
  flex \
  bc \
  libelf-dev \
  pahole \
  git \
  python3

RUN cd /tmp && \
  git clone 'https://github.com/microsoft/WSL2-Linux-Kernel.git' --branch linux-msft-wsl-$(uname -r | sed -E 's/^([0-9]\.[0-9]+).*/\1.y/g' ) --depth 1 --recurse-submodules && \
  cd /tmp/WSL2-Linux-Kernel && \
  make KCONFIG_CONFIG=Microsoft/config-wsl -j$(nproc) && \
  make modules_install && \
  make install
#  cd ..
#  sudo cp /boot/vmlinuz-$(uname -r) /mnt/c/Users/d_khrapun/vmlinuz-$(uname -r) && \
#  printf '[wsl2]\nkernel=C:\\\\Users\\\\d_khrapun\\\\vmlinuz-(uname -r)\n' | sudo tee --append /mnt/c/Users/d_khrapun/.wslconfig


# Get nginx source.
RUN cd /tmp && \
#  wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
  wget https://github.com/openresty/openresty/releases/download/v${OPENRESTY_VERSION}/openresty-${OPENRESTY_VERSION}.tar.gz && \
  tar zxf openresty-${OPENRESTY_VERSION}.tar.gz && rm openresty-${OPENRESTY_VERSION}.tar.gz

# Get Ngx Devel Kit
#RUN cd /tmp && \
#  wget https://github.com/vision5/ngx_devel_kit/archive/v${NGX_VERSION}.tar.gz && \
#  tar zxf v${NGX_VERSION}.tar.gz && rm v${NGX_VERSION}.tar.gz

# Get lua-nginx module
#RUN cd /tmp && \
#  wget https://github.com/openresty/lua-nginx-module/archive/v${LUA_NGINX_VERSION}.tar.gz && \
#  tar zxf v${LUA_NGINX_VERSION}.tar.gz && rm v${LUA_NGINX_VERSION}.tar.gz

# Get nginx-rtmp module.
RUN cd /tmp && \
  wget https://github.com/sergey-dryabzhinsky/nginx-rtmp-module/archive/v${NGINX_RTMP_VERSION}.tar.gz && \
  tar zxf v${NGINX_RTMP_VERSION}.tar.gz && rm v${NGINX_RTMP_VERSION}.tar.gz

# Get luajit module.
RUN cd /tmp && \
  wget https://github.com/openresty/luajit2/archive/v${LUAJIT_VERSION}.tar.gz && \
  tar zxf v${LUAJIT_VERSION}.tar.gz && rm v${LUAJIT_VERSION}.tar.gz

# Build and install luajit2
#RUN cd /tmp/luajit2-${LUAJIT_VERSION} && \
#  make -j$(nproc) PREFIX=/usr/luajit && \
#  make install PREFIX=/usr/luajit

# Compile nginx with nginx-rtmp module and Lua support
#RUN cd /tmp/nginx-${NGINX_VERSION} && \
RUN cd /tmp/openresty-${OPENRESTY_VERSION} && \
#  export LUAJIT_LIB=/usr/luajit/lib && \
#  export LUAJIT_INC=/usr/luajit/include/luajit-2.1 && \
  ./configure \
#  --with-ld-opt="-Wl,-rpath,${LUAJIT_LIB}" \
  --prefix=/usr/local/ \
  --add-module=/tmp/nginx-rtmp-module-${NGINX_RTMP_VERSION} \
#  --add-module=/tmp/ngx_devel_kit-${NGX_VERSION} \
#  --add-module=/tmp/lua-nginx-module-${LUA_NGINX_VERSION} \
#  --add-module=/tmp/luajit2-${LUAJIT_VERSION} \
  --conf-path=/etc/nginx/nginx.conf \
  --with-threads \
  --with-file-aio \
  --with-http_ssl_module \
  --with-debug \
  --with-cc-opt="-Wimplicit-fallthrough=0" && \
#  cd /tmp/nginx-${NGINX_VERSION} && make -j$(nproc) && make install
  cd /tmp/openresty-${OPENRESTY_VERSION} && make -j$(nproc) && make install

###############################
# Build the FFmpeg-build image.
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04 as build-ffmpeg
ARG FFMPEG_VERSION
ARG PREFIX=/usr/local
ARG NV_CODEC_VERSION

# FFmpeg build dependencies.
RUN apt update && apt install -y \
  autoconf \
  automake \
  build-essential \
  coreutils \
  cmake \
  git-core \
  libass-dev \
  libfreetype6-dev \
  libgnutls28-dev \
  libfdk-aac-dev \
  libmp3lame-dev \
  libnuma-dev \
  libogg-dev \
  libopus-dev \
  libsdl2-dev \
  libssl-dev \
  libtheora-dev \
  libtool \
  libva-dev \
  libvdpau-dev \
  libvorbis-dev \
  libvpx-dev \
  libwebp-dev \
  libx264-dev \
  libx265-dev \
  nasm \
  pkg-config \
  texinfo \
  wget \
  yasm \
  zlib1g-dev

RUN git clone https://git.videolan.org/git/ffmpeg/nv-codec-headers.git && \
  cd nv-codec-headers && \
  git checkout ${NV_CODEC_VERSION} && \
  make && \
  make install

# Get FFmpeg source.
RUN cd /tmp/ && \
  #wget http://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz && \
  wget https://github.com/FFmpeg/FFmpeg/archive/refs/tags/n${FFMPEG_VERSION}.tar.gz && \
  #wget https://nexcloud.nextime.su/sharing/Yl6pd8cpZ && \
  tar zxf n${FFMPEG_VERSION}.tar.gz && rm n${FFMPEG_VERSION}.tar.gz

# Compile ffmpeg.
RUN cd /tmp/FFmpeg-n${FFMPEG_VERSION} && \
  ./configure \
  --prefix=${PREFIX} \
  --enable-version3 \
  --enable-gpl \
  --enable-nonfree \
  --enable-small \
  --enable-libmp3lame \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx \
  --enable-libtheora \
  --enable-libvorbis \
  --enable-libopus \
  --enable-libfdk-aac \
  --enable-libass \
  --enable-libwebp \
  --enable-postproc \
  #--enable-avresample \
  --enable-libfreetype \
  --enable-openssl \
  --enable-nvenc \
  --enable-cuda \
  --enable-cuvid \
  --extra-cflags=-I/usr/local/cuda/include \
  --extra-ldflags=-L/usr/local/cuda/lib64 \
  --disable-debug \
  --disable-doc \
  --disable-ffplay \
  --extra-libs="-lpthread -lm" && \
  make -j$(nproc) && make install && make distclean

# Cleanup.
RUN rm -rf /var/cache/* /tmp/*

##########################
# Build the release image.
FROM nvidia/cuda:12.8.0-base-ubuntu22.04
LABEL MAINTAINER Marc Khouri <github@khouri.ca>

# Set default ports.
ENV HTTP_PORT 80
ENV HTTPS_PORT 443
ENV RTMP_PORT 1935

RUN apt update && apt install -y \
  ca-certificates \
  gettext \
  openssl \
  lame \
  libogg0 \
  curl \
  libass9 \
  libasound2 \
  libfdk-aac2 \
  libsdl2-2.0-0 \
  libsndio7.0 \
  libva2 \
  libvpx7 \
  libvorbis0a \
  libwebp7 \
  libtheora0 \
  libopus0 \
  libpcre3 \
  libxcb-shape0 \
  libxcb-xfixes0 \
  libxv1 \
  libva-drm2 \
  libva-x11-2 \
  libvdpau1 \
  libwebpmux3 \
  libx264-dev \
  libx265-dev \
#  luajit \
  rtmpdump \
  tzdata \
  hdhomerun-config

COPY --from=build-nginx /usr/local /usr/local
COPY --from=build-nginx /etc/nginx /etc/nginx
COPY --from=build-ffmpeg /usr/local /usr/local

# Add NGINX path, config and static files.
ENV PATH "${PATH}:/usr/local/nginx/sbin"
ADD nginx.conf /etc/nginx/nginx.conf.template
RUN mkdir -p /opt/data && mkdir /www
ADD static /www/static

EXPOSE 1935
EXPOSE 80

CMD envsubst "$(env | sed -e 's/=.*//' -e 's/^/\$/g')" < \
  /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf && \
  nginx
