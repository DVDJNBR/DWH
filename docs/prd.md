# <!-- Powered by BMAD™ Core -->
# ShopNow Data Warehouse - Brownfield Enhancement PRD

## Intro Project Analysis and Context

This PRD is for a significant enhancement to your existing project. My understanding is that the enhancement is to bring the ShopNow Data Warehouse into full compliance with the "B3 Datawarehouse" certification requirements by addressing identified gaps.

### Existing Project Overview

Based on `docs/brownfield-architecture.md`, the ShopNow Data Warehouse is a real-time data platform on Azure, transitioning from a centralized retail model to a multi-vendor Marketplace model. It uses Terraform, Azure Event Hubs, Azure Stream Analytics, and Azure SQL DB.

### Available Documentation Analysis

The `brownfield-architecture.md` itself serves as an initial analysis document.

*   Tech Stack Documentation: ✓ (Terraform, Azure services, Python)
*   Source Tree/Architecture: ✓ (Monorepo structure is documented)
*   Coding Standards: (Not explicitly detailed in `brownfield-architecture.md`, but generally expected in a project.)
*   API Documentation: (Implicit in Stream Analytics, but not formal API docs.)
*   External API Documentation: (Planned, but not current.)
*   UX/UI Guidelines: (N/A for a data warehouse.)
*   Technical Debt Documentation: ✓ (`brownfield-architecture.md` lists critical technical debt)

### Enhancement Scope Definition

**Enhancement Type:** Certification Compliance (addressing specific gaps in C13-C17).

**Enhancement Description:** To implement and document the necessary features and processes in the ShopNow Data Warehouse to meet all criteria for the B3 Datawarehouse certification.

**Impact Assessment:** Significant Impact (addressing multiple architectural and process gaps).

### Goals and Background Context

**Goals:**
*   Achieve full compliance with B3 Datawarehouse certification.
*   Demonstrate mastery of data warehousing concepts for a jury.
*   Improve the robustness and maintainability of the ShopNow Data Warehouse.

**Background Context:**
This enhancement is needed to prepare the existing ShopNow Data Warehouse project for a Data Engineer certification jury. It involves formalizing existing practices, implementing missing features (e.g., advanced historization, robust data quality, comprehensive monitoring), and creating necessary documentation to prove adherence to certification criteria (C13-C17).

## Requirements

### Rationale
These requirements are designed to directly address the missing items in your certification checklist. They focus on creating the necessary documentation (C13, C14, C15), implementing missing features for data quality and monitoring (C15, C16), and completing the advanced data historization (C17). Fulfilling these will provide the concrete evidence needed for your jury evaluation.

**Functional Requirements**

*   **FR1:** Formalize and document the data warehouse's logical and physical models, including schema diagrams. (Addresses C13)
*   **FR2:** Create and maintain a comprehensive, version-controlled test plan document. (Addresses C14)
*   **FR3:** Create and maintain a formal review document on the chosen tech stack, justifying its use. (Addresses C14)
*   **FR4:** Implement a data quarantine zone for data that fails quality checks, preventing it from entering the main warehouse. (Addresses C15)
*   **FR5:** Explicitly document all ETL business rules, transformations, and data cleaning processes. (Addresses C15)
*   **FR6:** Implement a monitoring dashboard (e.g., using Azure Dashboards) to display key service and performance indicators. (Addresses C16)
*   **FR7:** Implement an automated notification system (e.g., via Azure Monitor Action Groups) for critical alerts. (Addresses C16)
*   **FR8:** Create and maintain a GDPR compliance register documenting data treatments and procedures. (Addresses C16)
*   **FR9:** Complete the implementation and documentation of the SCD Type 2 historization for the `dim_vendor` dimension. (Addresses C17)

**Non-Functional Requirements**

*   **NFR1:** All new documentation must be in Markdown format and stored within the `/docs` directory of the repository.
*   **NFR2:** Access to the monitoring dashboard must be restricted to authorized personnel.

**Compatibility Requirements**

*   **CR1:** All enhancements must be compatible with the existing Azure infrastructure and be deployable via the existing Terraform workflow.

## Technical Constraints and Integration Requirements

### Rationale
Defining these constraints ensures that all new development aligns with your project's existing architecture and patterns. It prevents architectural drift and ensures that the new features for certification can be seamlessly integrated and deployed using your current `Makefile` and Terraform setup.

**Existing Technology Stack**

*   **Languages**: Python 3.12
*   **Frameworks**: Terraform >= 1.0
*   **Database**: Azure SQL DB (S0)
*   **Infrastructure**: Azure Event Hubs, Azure Stream Analytics, Azure Container Instances
*   **External Dependencies**: Python producers running in Docker.

**Integration Approach**

*   **Database Integration Strategy**: The new documentation and data quality features should not require breaking changes to the existing star schema. The SCD Type 2 implementation will alter the `dim_vendor` table as planned.
*   **API Integration Strategy**: N/A.
*   **Frontend Integration Strategy**: N/A.
*   **Testing Integration Strategy**: New tests for the quarantine zone and SCD logic should be added to the `scripts/tests/` directory and be executable via `make`.

**Code Organization and Standards**

*   **File Structure Approach**: New Terraform resources for monitoring should be added as a new module in `terraform/modules/`. New documentation will reside in `docs/`.
*   **Naming Conventions**: Follow existing conventions (e.g., `rg-e6-dbreau`, `asa-shopnow`).
*   **Coding Standards**: Follow existing Python and Terraform best practices.
*   **Documentation Standards**: All new documentation will be in Markdown format.

**Deployment and Operations**

*   **Build Process Integration**: New features should be deployable via new or existing `make` targets.
*   **Deployment Strategy**: Use the existing Terraform `apply` workflow.
*   **Monitoring and Logging**: The new dashboard and alerts will be built on top of the existing Azure Monitor and Stream Analytics logs.
*   **Configuration Management**: Continue using Terraform variables (`.tfvars`) for environment-specific configuration.

**Risk Assessment and Mitigation**

*   **Technical Risks**:
    *   SCD Type 2 implementation is complex and could impact ETL performance.
    *   Restarting Stream Analytics jobs to apply changes causes temporary data gaps.
*   **Integration Risks**: The data quarantine logic must be carefully designed to not block valid data.
*   **Deployment Risks**: Azure resources can enter a "soft-deleted" state, which can enter a "soft-deleted" state, which can block immediate redeployment with the same name.
*   **Mitigation Strategies**:
    *   Develop and test SCD Type 2 logic in a dedicated environment.
    *   Use `random_pet` in Terraform to avoid naming conflicts on redeployment.
    *   Schedule Stream Analytics updates during low-traffic periods.

## Epic and Story Structure

### Rationale
Structuring this work as a single epic ensures that all the individual tasks (implementing features, writing documentation) are tracked and managed as part of a single, cohesive goal: "Achieve B3 Certification Compliance." This makes it easier to see the overall progress and ensure no certification requirement is missed. It also aligns with the brownfield nature of the project, where changes need to be coordinated.

**Epic Approach**

**Epic Structure Decision**: This enhancement will be structured as a **single, comprehensive epic**. This is because all the requirements we've defined serve the single, unified goal of meeting the B3 Datawarehouse certification criteria.

## Epic 1: B3 Certification Compliance

**Epic Goal**: To implement all missing features and create all necessary documentation required to fully comply with the B3 Datawarehouse certification criteria (C13-C17).

**Integration Requirements**: All stories must be integrated into the existing Terraform and `make` workflow, ensuring no existing functionality is broken. Each story must include verification steps to prove existing features still work.

**Story 1.1: Formalize Core Warehouse Documentation**
*   **As a** project stakeholder,
*   **I want** all data models, test plans, and tech stack justifications to be formally documented,
*   **so that** the project meets C13 and C14 documentation requirements.
*   **Acceptance Criteria**:
    1.  A `docs/data_model.md` file is created with schema diagrams and justifications.
    2.  A `docs/test_plan.md` file is created detailing the testing strategy.
    3.  A `docs/tech_stack_review.md` file is created.
    4.  Existing `make deploy` and `make test` commands still function correctly.

**Story 1.2: Complete and Document SCD Type 2 Historization**
*   **As a** data architect,
*   **I want** to complete the implementation and documentation of the SCD Type 2 logic for the `dim_vendor` dimension,
*   **so that** data historization fully meets C17 requirements.
*   **Acceptance Criteria**:
    1.  The Stream Analytics query is updated to handle SCD Type 2 changes for vendors.
    2.  The `make test-vendors-stream` command successfully validates the new logic.
    3.  Documentation for the SCD Type 2 implementation is added to `docs/data_model.md`.
    4.  The existing order and clickstream processing is unaffected.

**Story 1.3: Implement Data Quality Quarantine**
*   **As a** data engineer,
*   **I want** a data quarantine zone implemented for the ETL process and all business rules documented,
*   **so that** data quality is guaranteed and the process complies with C15.
*   **Acceptance Criteria**:
    1.  A new storage mechanism (e.g., Azure Blob Storage) is created via Terraform to act as a quarantine.
    2.  The Stream Analytics job is modified to route malformed events to the quarantine.
    3.  A `docs/etl_rules.md` document is created, detailing the quality checks and business logic.
    4.  Valid data continues to flow into the data warehouse without interruption.

**Story 1.4: Implement Enhanced Monitoring and Alerting**
*   **As an** operations engineer,
*   **I want** a monitoring dashboard and an automated alert system for critical errors,
*   **so that** the warehouse's health can be effectively supervised, meeting C16 requirements.
*   **Acceptance Criteria**:
    1.  An Azure Dashboard is created via Terraform, monitoring key metrics (e.g., input/output events, errors).
    2.  An Azure Monitor Action Group is configured to send an email for any Stream Analytics job failure.
    3.  The dashboard and alerts are documented in a new `docs/monitoring.md` file.

**Story 1.5: Finalize GDPR Compliance Documentation**
*   **As a** compliance officer,
*   **I want** a formal GDPR register and associated procedures to be documented,
*   **so that** the project's data management is compliant with C16.
*   **Acceptance Criteria**:
    1.  A `docs/gdpr_compliance.md` file is created.
    2.  The document details all Personal Identifiable Information (PII) processed by the system.
    3.  The document outlines procedures for data access, rectification, and erasure.
