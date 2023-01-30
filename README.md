# Hello, World! (Deployed on ECS Fargate)

Terraform code to deploy and serve and application running on ECS Fargate.

## Architecture

![Alt text](images/ecs-fargate.png?raw=true "Architecture")

## Resources used

The Terraform code includes the following resources:
| Resource        | Description |
| ------------- |-------------|
| VPC      | Virtual private network to launch our resource in. Our Terraform identifies and uses the default VPC for our region. VPCs exist in one region but span multiple Availibility Zones. |
| Subnets      | Subnet (sub-network) is a smaller network in your VPC. Subnets can only be in one Availibility Zone. Subnets can be configured to be public (accessible from the internet) or private. Our subnets are configured to auto-assign IP settings, meaning a public IP is automatically requested for subnet's network interface. |
| Internet Gateway | Internet gateways are attached to VPCs to allow connections (inbound and outbound connections) between VPCs and the internet. An alternative to an Internet Gateway is a NAT Gateway, which only allows outbound connections. Our Terraform uses the default Internet Gateway associated with the default VPC. |
| Route Tables | Route tables contain rules (routes) used to determine how traffic is directed in our VPC. We're only using the main route table that comes with the default VPC. Our route table contains a local route for communication within the VPC and a route to direct all outbound traffic through our internet gateway.
| Network ACLs | Network Access Control Lists define what inbound and outbound traffic is allowed or denyed at a subnet level. Our subnets use the default Network ACLs which allow all traffic inbound and outbound.
| Security Groups | Security Groups define what traffic is allow to and from resources.
| Load Balancer | Load balancers accept incoming traffic and route it to resources, in this case ECS.
| Load Balancer Listener | Listeners check for connection requests on the defined protocol and port. In our code that HTTP traffic over port 80.
| Load Balancer Target Group | Target groups tell load balancers where to direct traffic to.
| ECS Cluster | Group of tasks or services. The underlying infrastructure can be provided by Fargate, EC2, on-prem servers or VMs/
| ECS Capacity Provider | Capacity providers defines which underlying infrastructure should be used.
| ECS Service | Collection of ECS tasks.
| Fargate Task | Defines the containers and allocated resources.
| CloudWatch | Our ECS tasks are configured to push logs to CloudWatch |

## Building and deploying the image with GitHub Actions

1. Fork this repo
2. Set up your [S3/DynamoDB backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3) 
3. Set the following secrets in Settings/Security/Secrets and variables/Actions:

| Variable | Description |
| ------------- |-------------|
| AWS_ACCESS_KEY_ID | access key for your AWS account |
| AWS_SECRET_ACCESS_KEY | secret access key for your AWS account |
| AWS_REGION | The AWS region to deploy your resources |
| BACKEND_DYNAMO_TABLE | dynamodb table to use for the backend|
| BACKEND_S3_BUCKET | S3 bucket to use for the backend |
| DOCKER_USERNAME | Username for authenticating to Docker Hub |
| DOCKER_PASSWORD | Password to authenticating to Docker Hub |
| DOCKER_REPO | Docker repository to push and pull images to/from e.g frazergibsonntt/aws-esc-fargate-docker |

4. Create a deploy and destroy environments (Settings/Code and automation/Environments). Tick the Required reviewer box and add yourself as the reviewer.
5. Navigate to Actions/Publish Docker image. Then Run workflow, leave the branch as main and type a tag to pass to the new image. This will trigger the pipeline.
6. Select the pipeline from the list. After the Push Docker image to Docker stage has run, click Review deployments, tick the box and then click Approve and deploy. This will deploy the the image on ECS Fargate.


##  Deploying from the command line

Use the commands below to deploy the infrastructure using the command line. Update the init command with your own backend configuration.

[Don't build image on Mac M1](https://stackoverflow.com/questions/67361936/exec-user-process-caused-exec-format-error-in-aws-fargate-service) 

Dependencies: aws cli, Terraform, Docker

Build the image:
```bash
docker build . -t <docker repo>:<image>
docker push <docker repo>:<image>
```

Deploy the terraform
```bash
aws configure
cd terraform
```

### Init

```bash
terraform init -no-color -force-copy -input=false -upgrade=true -backend=true \
  -backend-config="bucket=<BACKEND_S3_BUCKET>" \
  -backend-config="key=< state file name >.tfstate" \ # tf-${{ BACKEND_S3_BUCKET }}.tfstate in the pipeline
  -backend-config="region=<AWS_REGION>" \
  -backend-config="dynamodb_table=<BACKEND_DYNAMO_TABLE>" \
  -backend-config="encrypt=true"
```

### Plan

```bash
terraform plan -out=tfplan -var="image=<docker repo>:<image>"
```

### Apply

```bash
terraform apply -input=false -no-color -input=false tfplan 
```

### Delete

```bash
terraform plan -destroy -out=tfplan && \
terraform apply -destroy -input=false -no-color tfplan 
```


## Testing
### Docker
Useful commands for testing the Docker image locally

Run an image:
```bash
docker run --rm -it  -p 8000:8000/tcp <docker repo>:<image>
```

Run the image, but change the entrypoint and mount the pwd:
```bash
docker run --rm -it \
    --name test-pod \
    --network host \
    -p 8000:8000/tcp \
    -v $(pwd):/app \
    -w /app \
    --entrypoint "/bin/sh" \
    <docker repo>:<image>
```
The app will listen on port 8000.

http://127.0.0.1:8000

The greeting can be configured with an query parameter:

http://127.0.0.1:8000/?name=Dave

### CLI
Useful commands for testing locally from the cli

Requires Python 3.8 or later. The requirements can then be installed using pip:
```
python3.8 -m pip install -r requirements.txt
```

Running the app:

```
uvicorn hello.main:app
```

The app will listen on port 8000.

http://127.0.0.1:8000

The greeting can be configured with an query parameter:

http://127.0.0.1:8000/?name=Dave

