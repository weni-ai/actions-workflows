# Container image that runs your code
FROM alpine:3.10

RUN apk add --no-cache gnupg bash

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
