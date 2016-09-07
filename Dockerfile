FROM node
RUN apt-get update
RUN apt-get install -y kmod
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY package.json /usr/src/app/
RUN npm install
COPY . /usr/src/app

CMD [ "./start.sh" ]
