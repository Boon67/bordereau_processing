-- ============================================
-- Configure Keypair Authentication for DEMO_SVC
-- Run this as ACCOUNTADMIN or USERADMIN
-- ============================================

-- Switch to appropriate role (try USERADMIN first, then ACCOUNTADMIN if needed)
USE ROLE USERADMIN;

-- Set the RSA public key for the user
ALTER USER DEMO_SVC SET RSA_PUBLIC_KEY='MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwhAiuG3PF/XXPvplkAqQsaBzYrwjdAXwTCDhmZL0S3Xc0SH8jDffW4T1ckrU4ycKeoPL+LG/ISqUY+8MSRi30op9JQ2f5WDq48Kue37XDR9uCiy+oXwtvDb49psT7c4lins19QWd3fJQ4u/ZtMC25ifTkHs2XvQe6hq4TUa+VFmWQwVFFISqLVkYHgAVfgHVwwQzNly8rNmKCHKirFksxW2ACLBXqxJN8XuXwf0kI6HQdspI1Etn6MpjGBSQgp8LJBFcYYplXZWbBh3LJ7kUWaXyMrxjsF9Rjim8OxrrvjYnxpDem34yBERsvmmNSLtFosPrGrqiEf6vdtgWCzy+TQIDAQAB';

-- Verify the configuration
DESC USER DEMO_SVC;

-- Test query (optional)
SELECT 'Keypair authentication configured successfully for DEMO_SVC!' AS STATUS;
