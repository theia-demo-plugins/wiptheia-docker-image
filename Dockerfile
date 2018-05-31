# Copyright (c) 2018 Red Hat, Inc.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation

FROM node:8-alpine
# build dependencies requireed to compile a custom Theia
RUN apk update && apk add --no-cache make gcc g++ python git openssh bash sudo shadow && \
    rm -rf /tmp/* /var/cache/apk/* && \
    echo "%root ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    adduser -S user -h /home/theia -s /bin/bash -G root -u 1001 && \
    usermod -p "*" user

# Add the upstream package.json
ADD https://raw.githubusercontent.com/theia-ide/theia-apps/master/theia-full-docker/latest.package.json /home/theia/package.json
ADD theia-default-package.json /home/default/theia/package.json
ADD src/add-extensions.js /home/default
ADD src/main.js /theia_launcher/theia_launcher.js
RUN sudo chown -R user /home/theia /home/default
# Switch to user mode
USER user
ENV HOME /home/theia
WORKDIR /home/theia
# build Theia with all extensions to persist yarn cache in the image and
# have default Theia build in the workspace in case no plugins are requested
RUN sed -i -e 's/@theia/@wiptheia/g' /home/theia/package.json && \
    sed -i '/@wiptheia\/go/d' /home/theia/package.json && \
    cat /home/theia/package.json
RUN git clone https://github.com/eclipse/che-theia-hosted-plugin-manager-extension /tmp/hosted-plugin-extension && \
    node /home/default/add-extensions.js \
    @eclipse-che/che-theia-hosted-plugin-manager-extension:file:///tmp/hosted-plugin-extension \
    che-theia-ssh-extension:https://github.com/eclipse/che-theia-ssh-plugin.git && \
    rm /home/default/add-extensions.js && \
    cd /home/theia && \
    yarn && \
    yarn theia build && \
    rm -rf * && \
    cd /home/default/theia && \
    yarn && \
    yarn theia build
# Step to be sure to re-install the generator if there is a change on the repository
ADD https://api.github.com/repos/theia-demo-plugins/generator-theia-plugin/git/refs/heads/master /tmp/.sha1
RUN sudo npm install -g yo @wiptheia/generator-theia-plugin
EXPOSE 3000
ARG GITHUB_TOKEN
ENV USE_LOCAL_GIT=true \
    GITHUB_TOKEN=${GITHUB_TOKEN}
RUN for f in "/home/theia" "/etc/passwd" "/etc/group"; do\
           sudo chgrp -R 0 ${f} && \
           sudo chmod -R g+rwX ${f}; \
        done && \
        # Generate passwd.template \
        cat /etc/passwd | \
        sed s#user:x.*#user:x:\${USER_ID}:\${GROUP_ID}::\${HOME}:/bin/bash#g \
        > /home/theia/passwd.template && \
        # Generate group.template \
        cat /etc/group | \
        sed s#root:x:0:#root:x:0:0,\${USER_ID}:#g \
        > /home/theia/group.template
ENTRYPOINT ["node", "/theia_launcher/theia_launcher.js"]
