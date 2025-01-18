FROM golang:1.16-alpine3.12 AS build

RUN apk update && apk add git make rsync bash && \
    # Clone kubernetes repo with depth=1 for speed
    git clone --depth=1 https://github.com/kubernetes/kubernetes.git && \
    cd kubernetes && \
    make kubectl

FROM alpine:3.12
RUN apk update && apk add bash
COPY --from=build /go/kubernetes/_output/bin/kubectl /bin/
COPY rollout.sh /bin/
RUN chmod +x /bin/rollout.sh
CMD /bin/rollout.sh
