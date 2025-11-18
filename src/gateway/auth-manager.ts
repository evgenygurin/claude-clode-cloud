/**
 * AWS Authentication Manager
 * Handles multiple authentication methods for AWS Bedrock access
 *
 * Phase: WOR-10 - Authentication Methods
 * Purpose: Unified authentication interface supporting 4 methods
 */

import {
  STSClient,
  AssumeRoleCommand,
  GetCallerIdentityCommand,
} from "@aws-sdk/client-sts";
import { IAMClient } from "@aws-sdk/client-iam";
import { fromIni } from "@aws-sdk/credential-providers";
import { fromEnv } from "@aws-sdk/credential-providers";
import { fromContainerMetadata } from "@aws-sdk/credential-providers";

/**
 * Authentication method types
 */
export type AuthMethod = "aws_cli" | "iam_user" | "sts" | "sso";

/**
 * Base authentication configuration
 */
export interface AuthConfig {
  method: AuthMethod;
  region: string;
}

/**
 * AWS CLI credentials configuration
 * Uses ~/.aws/credentials and ~/.aws/config files
 */
export interface AWSCliConfig extends AuthConfig {
  method: "aws_cli";
  profile?: string;
  credentialsFile?: string;
  configFile?: string;
}

/**
 * IAM User access keys configuration
 * Direct access keys for programmatic use
 */
export interface IAMUserConfig extends AuthConfig {
  method: "iam_user";
  accessKeyId: string;
  secretAccessKey: string;
}

/**
 * STS temporary credentials configuration
 * Assume role for time-limited access
 */
export interface STSConfig extends AuthConfig {
  method: "sts";
  roleArn: string;
  sessionName?: string;
  durationSeconds?: number;
  externalId?: string;
  policy?: string;
}

/**
 * SSO (AWS IAM Identity Center) configuration
 * Federated access through AWS SSO
 */
export interface SSOConfig extends AuthConfig {
  method: "sso";
  startUrl: string;
  accountId: string;
  roleName: string;
  ssoRegion?: string;
}

/**
 * Unified authentication configuration type
 */
export type UnifiedAuthConfig =
  | AWSCliConfig
  | IAMUserConfig
  | STSConfig
  | SSOConfig;

/**
 * Credentials result from any authentication method
 */
export interface AuthCredentials {
  accessKeyId: string;
  secretAccessKey: string;
  sessionToken?: string;
  expiration?: Date;
  method: AuthMethod;
}

/**
 * Authentication error with details
 */
export class AuthenticationError extends Error {
  constructor(
    public method: AuthMethod,
    public reason: string,
    public details?: any
  ) {
    super(`Authentication failed (${method}): ${reason}`);
    this.name = "AuthenticationError";
  }
}

/**
 * Main Authentication Manager class
 * Provides unified interface for all authentication methods
 */
export class AuthenticationManager {
  private stsClient: STSClient;
  private config: UnifiedAuthConfig;

  constructor(config: UnifiedAuthConfig) {
    this.config = config;
    this.stsClient = new STSClient({ region: config.region });
  }

  /**
   * Get credentials using configured authentication method
   */
  async getCredentials(): Promise<AuthCredentials> {
    switch (this.config.method) {
      case "aws_cli":
        return this.getAWSCliCredentials();
      case "iam_user":
        return this.getIAMUserCredentials();
      case "sts":
        return this.getSTSCredentials();
      case "sso":
        return this.getSSOCredentials();
      default:
        throw new AuthenticationError(
          this.config.method,
          "Unknown authentication method"
        );
    }
  }

  /**
   * Method 1: AWS CLI Credentials
   * Reads from ~/.aws/credentials and ~/.aws/config
   *
   * Advantages:
   * - Uses existing AWS CLI configuration
   * - No secrets in code
   * - Works with MFA and profiles
   * - Most common and user-friendly
   *
   * Setup:
   * 1. Install AWS CLI: brew install awscli
   * 2. Configure: aws configure
   * 3. Verify: aws sts get-caller-identity
   */
  private async getAWSCliCredentials(): Promise<AuthCredentials> {
    try {
      const config = this.config as AWSCliConfig;
      const profile = config.profile || "default";

      // Load credentials from ~/.aws/credentials using profile
      const credentials = await fromIni({
        profile: profile,
        mfaCodeProvider: async (mfaSerial) => {
          // For MFA-protected accounts, you'd need to implement MFA code input
          throw new Error(
            `MFA is enabled for profile ${profile}. Use environment variables or other methods.`
          );
        },
      })();

      // Verify credentials work
      await this.verifyCredentials(credentials);

      return {
        accessKeyId: credentials.accessKeyId,
        secretAccessKey: credentials.secretAccessKey,
        sessionToken: credentials.sessionToken,
        expiration: credentials.expiration,
        method: "aws_cli",
      };
    } catch (error) {
      throw new AuthenticationError(
        "aws_cli",
        "Failed to load credentials from ~/.aws/credentials",
        error
      );
    }
  }

  /**
   * Method 2: IAM User Access Keys
   * Direct access key ID and secret access key
   *
   * Advantages:
   * - Direct and simple
   * - Good for CI/CD pipelines
   * - No interactive setup needed
   *
   * Setup:
   * 1. Create IAM user in AWS Console
   * 2. Generate access keys
   * 3. Set environment variables:
   *    export AWS_ACCESS_KEY_ID=AKIA...
   *    export AWS_SECRET_ACCESS_KEY=...
   * 4. Or configure in .env file
   *
   * Security:
   * - NEVER commit keys to git
   * - Rotate keys regularly
   * - Use least privilege policy
   * - Enable MFA for console access
   */
  private async getIAMUserCredentials(): Promise<AuthCredentials> {
    try {
      const config = this.config as IAMUserConfig;

      // Validate keys are provided
      if (!config.accessKeyId || !config.secretAccessKey) {
        throw new Error("Access key ID and secret access key are required");
      }

      const credentials = {
        accessKeyId: config.accessKeyId,
        secretAccessKey: config.secretAccessKey,
      };

      // Verify credentials work
      await this.verifyCredentials(credentials);

      return {
        accessKeyId: credentials.accessKeyId,
        secretAccessKey: credentials.secretAccessKey,
        method: "iam_user",
      };
    } catch (error) {
      throw new AuthenticationError(
        "iam_user",
        "Failed to verify IAM user credentials",
        error
      );
    }
  }

  /**
   * Method 3: STS Assume Role
   * Temporary credentials by assuming an IAM role
   *
   * Advantages:
   * - Temporary credentials (1-12 hours)
   * - Fine-grained access control
   * - Better for cross-account access
   * - Audit trail in CloudTrail
   *
   * Setup:
   * 1. Create IAM role with trust relationship
   * 2. Attach Bedrock access policy to role
   * 3. Set base credentials (AWS CLI or IAM user)
   * 4. Configure role ARN and session name
   *
   * Use case:
   * - Temporary access for Lambda functions
   * - Cross-account Bedrock access
   * - Delegated permissions for teams
   *
   * Example:
   * roleArn: arn:aws:iam::123456789012:role/BedrockRole
   * sessionName: cursor-agent-session
   * durationSeconds: 3600
   */
  private async getSTSCredentials(): Promise<AuthCredentials> {
    try {
      const config = this.config as STSConfig;

      // Get base credentials first (AWS CLI or IAM user)
      const baseAuth =
        process.env.AWS_ACCESS_KEY_ID && process.env.AWS_SECRET_ACCESS_KEY
          ? ({ method: "iam_user" } as IAMUserConfig)
          : ({ method: "aws_cli", profile: "default" } as AWSCliConfig);

      const baseAuth_: UnifiedAuthConfig = { ...baseAuth, region: config.region };
      const baseManager = new AuthenticationManager(baseAuth_);
      const baseCredentials = await baseManager.getCredentials();

      // Assume role using base credentials
      const assumeRoleCommand = new AssumeRoleCommand({
        RoleArn: config.roleArn,
        RoleSessionName: config.sessionName || "cursor-agent-session",
        DurationSeconds: config.durationSeconds || 3600,
        ExternalId: config.externalId,
        Policy: config.policy,
      });

      const response = await this.stsClient.send(assumeRoleCommand);

      if (!response.Credentials) {
        throw new Error("No credentials returned from STS AssumeRole");
      }

      return {
        accessKeyId: response.Credentials.AccessKeyId!,
        secretAccessKey: response.Credentials.SecretAccessKey!,
        sessionToken: response.Credentials.SessionToken!,
        expiration: response.Credentials.Expiration,
        method: "sts",
      };
    } catch (error) {
      throw new AuthenticationError(
        "sts",
        "Failed to assume role",
        error
      );
    }
  }

  /**
   * Method 4: AWS SSO (IAM Identity Center)
   * Federated access through AWS Single Sign-On
   *
   * Advantages:
   * - Enterprise single sign-on
   * - Managed permission sets
   * - Centralized access control
   * - No long-lived credentials
   *
   * Setup:
   * 1. Enable AWS IAM Identity Center
   * 2. Configure SSO provider (Okta, Azure AD, etc.)
   * 3. Create permission sets
   * 4. Assign users to accounts
   * 5. Configure AWS CLI: aws sso configure
   *
   * Profile configuration (~/.aws/config):
   * [profile sso-profile]
   * sso_start_url = https://d-xxx.awsapps.com/start
   * sso_region = us-east-1
   * sso_account_id = 123456789012
   * sso_role_name = BedrockAccess
   * region = us-east-1
   *
   * Use case:
   * - Enterprise teams
   * - Multi-account environments
   * - Compliance and audit requirements
   */
  private async getSSOCredentials(): Promise<AuthCredentials> {
    try {
      const config = this.config as SSOConfig;

      // Use AWS SDK's built-in SSO credential provider
      const credentials = await fromIni({
        profile: "sso-profile", // This should be configured in ~/.aws/config
      })();

      // Verify credentials work
      await this.verifyCredentials(credentials);

      return {
        accessKeyId: credentials.accessKeyId,
        secretAccessKey: credentials.secretAccessKey,
        sessionToken: credentials.sessionToken,
        expiration: credentials.expiration,
        method: "sso",
      };
    } catch (error) {
      throw new AuthenticationError(
        "sso",
        "Failed to load SSO credentials",
        error
      );
    }
  }

  /**
   * Verify that credentials are valid
   * Makes a test call to STS GetCallerIdentity
   */
  private async verifyCredentials(credentials: any): Promise<void> {
    try {
      const stsClient = new STSClient({
        region: this.config.region,
        credentials: credentials,
      });

      const command = new GetCallerIdentityCommand({});
      await stsClient.send(command);
    } catch (error) {
      throw new Error("Credentials verification failed");
    }
  }

  /**
   * Test all authentication methods to find which ones work
   */
  static async testAllMethods(region: string = "us-east-1"): Promise<void> {
    console.log("🧪 Testing all authentication methods...\n");

    // Test 1: AWS CLI
    try {
      console.log("1️⃣  Testing AWS CLI credentials...");
      const cliManager = new AuthenticationManager({
        method: "aws_cli",
        region,
        profile: "default",
      });
      const cliCreds = await cliManager.getCredentials();
      console.log("✅ AWS CLI: OK\n");
    } catch (error) {
      console.log(
        `❌ AWS CLI: ${error instanceof AuthenticationError ? error.reason : String(error)}\n`
      );
    }

    // Test 2: IAM User (from environment)
    try {
      if (process.env.AWS_ACCESS_KEY_ID && process.env.AWS_SECRET_ACCESS_KEY) {
        console.log("2️⃣  Testing IAM User credentials...");
        const iamManager = new AuthenticationManager({
          method: "iam_user",
          region,
          accessKeyId: process.env.AWS_ACCESS_KEY_ID,
          secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
        });
        const iamCreds = await iamManager.getCredentials();
        console.log("✅ IAM User: OK\n");
      } else {
        console.log(
          "⏭️  IAM User: Skipped (no AWS_ACCESS_KEY_ID in environment)\n"
        );
      }
    } catch (error) {
      console.log(
        `❌ IAM User: ${error instanceof AuthenticationError ? error.reason : String(error)}\n`
      );
    }

    // Test 3: STS (requires base credentials)
    try {
      if (process.env.AWS_ROLE_ARN) {
        console.log("3️⃣  Testing STS AssumeRole...");
        const stsManager = new AuthenticationManager({
          method: "sts",
          region,
          roleArn: process.env.AWS_ROLE_ARN,
          sessionName: "test-session",
        });
        const stsCreds = await stsManager.getCredentials();
        console.log("✅ STS: OK\n");
      } else {
        console.log("⏭️  STS: Skipped (no AWS_ROLE_ARN in environment)\n");
      }
    } catch (error) {
      console.log(
        `❌ STS: ${error instanceof AuthenticationError ? error.reason : String(error)}\n`
      );
    }

    // Test 4: SSO
    try {
      console.log("4️⃣  Testing AWS SSO...");
      const ssoManager = new AuthenticationManager({
        method: "sso",
        region,
        startUrl: "https://placeholder.awsapps.com/start",
        accountId: "123456789012",
        roleName: "BedrockAccess",
      });
      const ssoCreds = await ssoManager.getCredentials();
      console.log("✅ SSO: OK\n");
    } catch (error) {
      console.log(
        `❌ SSO: ${error instanceof AuthenticationError ? error.reason : String(error)}\n`
      );
    }

    console.log("🧪 Authentication testing complete!");
  }
}

// Export types and classes
export default AuthenticationManager;
export { AuthenticationError };
