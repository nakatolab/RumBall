tag=0.5.1
docker build -f Dockerfile.$tag -t rnakato/rumball:$tag . #--no-cache
exit

docker push rnakato/rumball:$tag
docker tag rnakato/rumball:$tag rnakato/rumball:latest
docker push rnakato/rumball
