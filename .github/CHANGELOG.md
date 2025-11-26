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
