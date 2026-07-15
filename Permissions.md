# Permissions

This package is self-contained except for the incoming AWS permissions: the
autoscaler calls the Auto Scaling, EC2 and EKS APIs directly, so its pod must
receive an IAM role. Provision that role and its delivery outside this package.

## IAM role contents

The recommended full-features policy from the [upstream IAM Policy](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md#iam-policy) section:

The first statement is read-only discovery, safe on `Resource: ["*"]`. The
second holds the mutating actions - restrict it to your ASG ARNs (or tag
conditionals) as upstream strongly recommends. Edit the region, account id
and ASG names before use:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeScalingActivities",
        "ec2:DescribeImages",
        "ec2:DescribeInstanceTypes",
        "ec2:DescribeLaunchTemplateVersions",
        "ec2:GetInstanceTypesFromInstanceRequirements",
        "eks:DescribeNodegroup"
      ],
      "Resource": ["*"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup"
      ],
      "Resource": [
        "arn:aws:autoscaling:eu-west-1:111122223333:autoScalingGroup:*:autoScalingGroupName/my-cluster-workers-a",
        "arn:aws:autoscaling:eu-west-1:111122223333:autoScalingGroup:*:autoScalingGroupName/my-cluster-workers-b"
      ]
    }
  ]
}
```

This is available as a [tokenised JSON file](Permissions.json) in the root of this repo.
## Delivering the role to the pod

1. **EKS Pod Identity** - associate the IAM role with this package's
   ServiceAccount named `vendor-cluster-autoscaler-aws` using a pod identity
   association on the AWS side. Nothing changes in this package.
2. **IRSA** - the ServiceAccount ships with a role-arn annotation whose key
   defaults to a decoy value of `disabled-for-pod-identity.eks.amazonaws.com/role-arn`,
   which the EKS pod identity webhook never matches, so it is inert under Pod
   Identity. To enable IRSA, override per environment:
   - `VendorClusterAutoscalerAws/IrsaAnnotationKey` to `eks.amazonaws.com/role-arn` (default is prefixed for pod identity)
   - `VendorClusterAutoscalerAws/AwsAccountId` to your account id (default is obviously fake `424242424242`)
   - `VendorClusterAutoscalerAws/IrsaRoleName` if the role is env name prefixed (default is `vendor-cluster-autoscaler-aws`)
   - `VendorClusterAutoscalerAws/AwsArnPartition` if you're on gov or china (default `aws`)

   See upstream [Using OIDC Federated Authentication](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md#using-oidc-federated-authentication).
