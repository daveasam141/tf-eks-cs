### Docker image for custom jenkins agent 

## Docker build 
docker build -t your-dockerhub-username/jenkinscustom-agent:latest .

## Ensure that image is built
docker image ls 

## docker login
docker login 

# Push the image
docker push your-dockerhub-username/jenkinscustom-agent:latest

docker buildx build \
  --platform linux/amd64 \
  -f Dockerfile \
  -t davidasam141/jenkinscustom-agent-2:latest \
  --push \
  .