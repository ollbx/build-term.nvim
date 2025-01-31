FROM alpine:latest AS build

RUN apk add chromium
RUN apk add neovim
RUN apk add font-jetbrains-mono
RUN apk add bash
RUN apk add ffmpeg
RUN apk add go
RUN apk add rust
RUN apk add cargo
RUN apk add ttyd
RUN apk add git

RUN addgroup -S demo && adduser -S demo -G demo

USER demo
RUN go install github.com/charmbracelet/vhs@latest

WORKDIR /home/demo
RUN cargo new --bin demo

ADD init.lua /home/demo/.config/nvim/init.lua
ADD main.rs /home/demo/demo/src/main.rs

USER root
RUN chown -R demo:demo /home/demo/.config
RUN chown demo:demo /home/demo/demo/src/main.rs

USER demo
RUN nvim --headless "+Lazy! sync" +qa

ENV PATH="$PATH:/home/demo/go/bin/"
ENV VHS_NO_SANDBOX="true"
ENV PS1='\[\033[01;32m\]\u\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

WORKDIR /home/demo/demo
RUN cargo build; exit 0

ADD demo.tape .
RUN vhs demo.tape

FROM scratch
COPY --from=build /home/demo/demo/demo.webm /
