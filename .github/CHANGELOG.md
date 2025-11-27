# [2.1.0-beta.1](https://github.com/DVDJNBR/DWH/compare/v2.0.4...v2.1.0-beta.1) (2025-11-27)


### Bug Fixes

* add missing CYAN color in test_marketplace_schema.py ([6d7e4cb](https://github.com/DVDJNBR/DWH/commit/6d7e4cb28d2dd10dc017524e6f3b3ef3f4db5735))


### Features

* add seed_vendors.py with Faker for realistic vendor data ([4277477](https://github.com/DVDJNBR/DWH/commit/4277477d6311eb594fb91b088c131ae2a957bb8a))
* merge FT/STREAM_NEW_VENDORS into DEV ([0ea41a9](https://github.com/DVDJNBR/DWH/commit/0ea41a973d6c0be2568ea0d6d90fdfca7a3264a2))

## [2.0.4](https://github.com/DVDJNBR/DWH/compare/v2.0.3...v2.0.4) (2025-11-27)


### Bug Fixes

* correct terraform path in test_backup_restore.py ([63c5565](https://github.com/DVDJNBR/DWH/commit/63c556505f6eaaccdf4bc2b089dc927ed83d8d5c))

## [2.0.3](https://github.com/DVDJNBR/DWH/compare/v2.0.2...v2.0.3) (2025-11-27)


### Bug Fixes

* correct .env path in test_backup_restore.py ([d4b2aad](https://github.com/DVDJNBR/DWH/commit/d4b2aade57fecff31a372c1356d9d770ca30a640))

## [2.0.2](https://github.com/DVDJNBR/DWH/compare/v2.0.1...v2.0.2) (2025-11-27)


### Bug Fixes

* add ENV=dev default variable in Makefile ([533ecf1](https://github.com/DVDJNBR/DWH/commit/533ecf1832d3cdda8bf3e4dbdf98c9978be46c7a))

## [2.0.1](https://github.com/DVDJNBR/DWH/compare/v2.0.0...v2.0.1) (2025-11-27)


### Bug Fixes

* rename apply-backup to recovery-setup and clarify ENV defaults ([c596b6d](https://github.com/DVDJNBR/DWH/commit/c596b6d0c1ecc2a390abd1bc3ad7b1bf47c7a427))

# [2.0.0](https://github.com/DVDJNBR/DWH/compare/v1.0.0...v2.0.0) (2025-11-26)


* feat!: add marketplace schema with incremental migration ([0fe9fd3](https://github.com/DVDJNBR/DWH/commit/0fe9fd38f19586289730056c65b954480ab1e94e))


### Features

* add marketplace schema migration ([3debee8](https://github.com/DVDJNBR/DWH/commit/3debee82abe2cd498b9a06467c0ebb21bc98d487))


### BREAKING CHANGES

* Database schema extended with marketplace tables

This major release adds multi-vendor marketplace support:

Schema changes:
- New dimension: dim_vendor with SCD Type 2 (historical tracking)
- New facts: fact_vendor_performance, fact_stock
- Modified: dim_product extended with vendor_id
- Row-Level Security (RLS) for vendor data isolation

Migration features:
- Incremental deployment (no data loss)
- Backward compatible (existing products linked to SHOPNOW)
- Idempotent SQL migration script
- Automated testing with before/after comparison

Testing:
- make test-base: validates base schema
- make test-schema: validates marketplace schema with comparison
- Detailed reports with data samples and structure

Workflow:
1. make deploy (base infrastructure)
2. make seed (historical data)
3. make apply-backup (add backup incrementally)
4. make update-schema (add marketplace tables incrementally)
5. make test-schema (validate changes)

The infrastructure now supports multi-vendor marketplace with
production-grade security and data isolation.

# [1.0.0](https://github.com/DVDJNBR/DWH/compare/v0.4.0...v1.0.0) (2025-11-26)


* feat!: add production-ready disaster recovery ([1ad6f74](https://github.com/DVDJNBR/DWH/commit/1ad6f7477614a8dc36e523d3be64d03ede8a026c))


### Features

* add backup restore test script ([37bb29e](https://github.com/DVDJNBR/DWH/commit/37bb29ee758368010b81f8fb2aa7c48031962dca))
* add disaster recovery with environment-based backup configuration ([82a0b80](https://github.com/DVDJNBR/DWH/commit/82a0b80fb7ed49f161ca853c73d0748b86fb02ae))


### BREAKING CHANGES

* Infrastructure now requires backup configuration

This major release adds comprehensive disaster recovery capabilities:
- Automated backup with configurable retention (dev/prod)
- Point-in-Time Restore tested and validated
- Geo-replication for regional failures
- RTO: 4 hours / RPO: 1 hour
- Environment-based configuration (dev/prod)

The infrastructure is now production-ready with enterprise-grade
backup and recovery features.

# [0.4.0](https://github.com/DVDJNBR/DWH/compare/v0.3.0...v0.4.0) (2025-11-25)


### Features

* add historical data seeding script with .env support ([4c35904](https://github.com/DVDJNBR/DWH/commit/4c359045ae0b170d288dfd47b6bbaade55e5a98a))

# [0.3.0](https://github.com/DVDJNBR/DWH/compare/v0.2.0...v0.3.0) (2025-11-25)


### Features

* add Makefile for easy Terraform management ([36a17e6](https://github.com/DVDJNBR/DWH/commit/36a17e610c7df8dc309a30885db1593d41ffa9f5))

# [0.2.0](https://github.com/DVDJNBR/DWH/compare/v0.1.0...v0.2.0) (2025-11-24)


### Bug Fixes

* correct branch name in semantic-release config ([9140f37](https://github.com/DVDJNBR/DWH/commit/9140f3775901464265c11fc57e8b82d67ed3ba68))
* correct branch names in release workflow ([2f4f369](https://github.com/DVDJNBR/DWH/commit/2f4f369e9d443354d4c735ae51a61929e384cfa5))


### Features

* add missing outputs for terraform modules ([cb750aa](https://github.com/DVDJNBR/DWH/commit/cb750aa95f33d76abb11bacd0067b4e135da1f99))
* add semantic-release automation ([4b1ad65](https://github.com/DVDJNBR/DWH/commit/4b1ad653c5305b630d65acdaae25e0896213019d))
* **terraform:** add complete infrastructure setup ([2760c67](https://github.com/DVDJNBR/DWH/commit/2760c6700f01b8e509f8f56b28f7e7d92c8bae5e))
