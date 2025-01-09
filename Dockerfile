##########################################
#         构建基础镜像                   #
##########################################
FROM danxiaonuo/ubuntu:latest AS builder

WORKDIR /app

ADD tailscale /app/tailscale

# build modified derper
RUN cd /app/tailscale/cmd/derper && \
    CGO_ENABLED=0 go build -buildvcs=false -ldflags "-s -w" -o /app/derper && \
    cd /app && \
    rm -rf /app/tailscale

##########################################
#         基础镜像                       #
##########################################
FROM danxiaonuo/ubuntu:latest

WORKDIR /app

# ========= CONFIG =========

# - derper args
ENV DERP_DOMAIN 127.0.0.1
ENV DERP_CERT_MODE manual
ENV DERP_CERT_DIR /app/certs
ENV DERP_ADDR :6699
ENV DERP_STUN true
ENV DERP_STUN_PORT 6677
ENV DERP_HTTP_PORT -1
ENV DERP_VERIFY_CLIENTS false
# ==========================

COPY build_cert.sh /app/
COPY --from=builder /app/derper /app/derper

# build self-signed certs && start derper
CMD bash /app/build_cert.sh $DERP_DOMAIN $DERP_CERT_DIR /app/san.conf && \
    /app/derper --hostname=$DERP_DOMAIN \
    --certmode=$DERP_CERT_MODE \
    --certdir=$DERP_CERT_DIR \
    --stun=$DERP_STUN  \
    --stun-port=$DERP_STUN_PORT \
    --a=$DERP_ADDR \
    --http-port=$DERP_HTTP_PORT \
    --verify-clients=$DERP_VERIFY_CLIENTS

# ***** 安装依赖 *****
RUN set -eux && \
   # 更新系统软件
   DEBIAN_FRONTEND=noninteractive apt-get update -qqy && apt-get upgrade -qqy && \
   rm -rf /var/lib/apt/lists/* && \
   # 更新时区
   ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
   # 更新时间
   echo ${TZ} > /etc/timezone && \
   # 更改为zsh
   sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true && \
   sed -i -e "s/bin\/ash/bin\/zsh/" /etc/passwd && \
   sed -i -e 's/mouse=/mouse-=/g' /usr/share/vim/vim*/defaults.vim && \
   locale-gen zh_CN.UTF-8 && localedef -f UTF-8 -i zh_CN zh_CN.UTF-8 && locale-gen && \
   /bin/zsh
