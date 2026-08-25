FROM ghcr.io/cirruslabs/android-sdk:36

USER root

ENV FLUTTER_HOME=/opt/flutter
ENV PATH=$PATH:$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin

RUN git clone --depth 1 --branch 3.47.0 https://github.com/flutter/flutter.git $FLUTTER_HOME

RUN yes | flutter doctor --android-licenses

RUN flutter precache --android

WORKDIR /app
