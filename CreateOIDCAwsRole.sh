# 1. Create the OIDC Provider
GITHUB_ORG=nullplatform-implementations
GITHUB_REPO_NAME=static-scope-app

GITHUB_REPO="$GITHUB_ORG/$GITHUB_REPO_NAME:ref:refs/heads/*"

POLICY_NAME=gha-$GITHUB_ORG-$GITHUB_REPO_NAME-policy
ROLE_NAME=gha-$GITHUB_ORG-$GITHUB_REPO_NAME-role

# 2. Get the OIDC Provider ARN
OIDC_PROVIDER_ARN=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn" --output text)

# 3. Create the IAM policy for the workflow permissions
cat > s3-permissions-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3BucketAccess",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::assets-aws-services-main",
        "arn:aws:s3:::assets-aws-services-main/*"
      ]
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name "$POLICY_NAME" \
  --policy-document file://s3-permissions-policy.json \
  --description "Policy for GitHub Actions to build and deploy $GITHUB_ORG/$GITHUB_REPO_NAME"

# 4. Get the policy ARN
POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)

# 5. Create the assume role policy document (works with any branch)
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:$GITHUB_REPO"
        },
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

# 6. Create the IAM Role
aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document file://trust-policy.json \
  --max-session-duration 3600 \
  --tags Key=Name,Value="$ROLE_NAME" Key=ManagedBy,Value=infra-as-code

# 7. Attach the policy to the role
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn $POLICY_ARN

# 8. Display the Role ARN (you'll need this for your GitHub Actions workflow)
echo "=========================================="
echo "Setup complete!"
echo "Role ARN: $(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)"
echo "=========================================="