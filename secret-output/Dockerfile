# Container image that runs your code
FROM alpine:3.22

RUN apk add --no-cache gnupg bash yq-go

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
