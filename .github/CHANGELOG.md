# [2.1.0-beta.7](https://github.com/DVDJNBR/DWH/compare/v2.1.0-beta.6...v2.1.0-beta.7) (2026-02-16)


### Bug Fixes

* replace bare except with Exception ([143d6e7](https://github.com/DVDJNBR/DWH/commit/143d6e721c1742e32d9a891a1e9c1bbb0fe67b98))

# [2.1.0-beta.6](https://github.com/DVDJNBR/DWH/compare/v2.1.0-beta.5...v2.1.0-beta.6) (2026-02-16)


### Bug Fixes

* resolve numerous linting and logic issues in tests and data-generator ([1fc5b75](https://github.com/DVDJNBR/DWH/commit/1fc5b7527d403ee6bc31236b8cf2ff8348d897a5))

# [2.1.0-beta.5](https://github.com/DVDJNBR/DWH/compare/v2.1.0-beta.4...v2.1.0-beta.5) (2026-02-16)


### Bug Fixes

* resolve type mismatch in marketplace producer and add pyrightconfig ([c818868](https://github.com/DVDJNBR/DWH/commit/c818868a3c1170001038ca1d454cf03e82dc435a))

# [2.1.0-beta.4](https://github.com/DVDJNBR/DWH/compare/v2.1.0-beta.3...v2.1.0-beta.4) (2026-02-16)


### Bug Fixes

* resolve linting errors (type mismatches, unused imports, operator issues) ([bf0e314](https://github.com/DVDJNBR/DWH/commit/bf0e3145426e601c7ba327ab24fbb7582f2100ce))

# [2.1.0-beta.3](https://github.com/DVDJNBR/DWH/compare/v2.1.0-beta.2...v2.1.0-beta.3) (2026-01-22)


### Bug Fixes

* change IP detection service from ipify to ifconfig.me ([6a33a87](https://github.com/DVDJNBR/DWH/commit/6a33a875ecdd77082fadee93b66267dd5eabe83a))
* **monitoring:** filter activity log alert by Succeeded status to avoid multiple emails ([83c3b2a](https://github.com/DVDJNBR/DWH/commit/83c3b2afcba18b2ac22b5efa0c2dee5e1768bbd9))
* resolve migration numbering conflict (003 -> 004) ([a11e0d7](https://github.com/DVDJNBR/DWH/commit/a11e0d713318dfa48fc834b4051ea04d9da0ca37))


### Features

* add marketplace Stream Analytics test suite ([101744b](https://github.com/DVDJNBR/DWH/commit/101744b71a7711489c92c97725f80d6aca26f15b))
* fix SCD Type 2 product migration and pipeline ([11497a0](https://github.com/DVDJNBR/DWH/commit/11497a05ed3a8d4ce1e80a523afcfc83e6daf4b8))
* Implement enhanced monitoring and fix stream analytics alerts ([9dca334](https://github.com/DVDJNBR/DWH/commit/9dca334ba818fa9a4b92ca80ead2f0e0a7b4c54e))
* optimize monitoring alerts to reduce noise ([4f9ebbd](https://github.com/DVDJNBR/DWH/commit/4f9ebbd9ed30759921e1d2c846065fde170c3605))
* **scd2:** Implement SCD Type 2 for dim_product ([6004405](https://github.com/DVDJNBR/DWH/commit/600440598b6504f084688a7474b1c649f7f00f4a))
* Unify marketplace producer and add quarantine test ([baeed49](https://github.com/DVDJNBR/DWH/commit/baeed49a07359c4c23c8db181747d9eb90d984a8))

# [2.1.0-beta.2](https://github.com/DVDJNBR/DWH/compare/v2.1.0-beta.1...v2.1.0-beta.2) (2026-01-20)


### Features

* add categorized help menu in English ([cec0e49](https://github.com/DVDJNBR/DWH/commit/cec0e49ae944d54511f70d4a54ebef79d6ab3097))
* add marketplace producer with vendor_id support ([39e037d](https://github.com/DVDJNBR/DWH/commit/39e037dc56d6ece89ae1ddbff7b837d9bd6e2d23))
* add quick backup test for faster validation ([13e9735](https://github.com/DVDJNBR/DWH/commit/13e973529b365371b95c4b8972cd254ecbb56c34))
* add vendor streaming with make stream-new-vendors ([14661f5](https://github.com/DVDJNBR/DWH/commit/14661f52a777c868acd01fb87e849433cfb0cf5c))
* **marketplace:** implement two-stream architecture with vendor_id support ([9a37c63](https://github.com/DVDJNBR/DWH/commit/9a37c63c4d94a8446a430d3ba367f781686fda45))
* **quarantine:** Implement data quality quarantine ([de224d0](https://github.com/DVDJNBR/DWH/commit/de224d0aac79bed03bf728b37e4c9d2c0b2ab64a))

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
