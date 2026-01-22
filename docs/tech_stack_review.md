# Data Warehouse Tech Stack Review

This document provides a review of the technology stack used in the ShopNow Data Warehouse, with justifications for each choice.

## Technical Summary

The ShopNow DWH is a real-time data platform on Azure. It ingests simulated e-commerce events (Orders, Clicks), transforms them on the fly, and persists them into a Star Schema in an Azure SQL Database.

## Technology Stack and Justifications

| Category       | Technology             | Justification                                                                                                                                     |
| :------------- | :--------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Infrastructure** | Terraform (>= 1.0)     | Infrastructure as Code (IaC) allows for repeatable, version-controlled, and automated environment provisioning, which is a core requirement for a robust data platform. |
| **Ingestion**      | Azure Event Hubs       | Provides a scalable and reliable entry point for high-throughput event streaming, capable of handling real-time e-commerce traffic. |
| **ETL / Stream**   | Azure Stream Analytics | Offers a SQL-like query language for real-time data transformation, making it easy to develop and maintain the ETL logic without a separate compute cluster. |
| **Database**       | Azure SQL DB           | A managed relational database service that supports standard SQL and provides a robust, secure, and scalable foundation for the star schema data model. |
| **Data Source**    | Python / Docker        | Python is a versatile language for data generation and scripting. Docker allows for packaging the data producers into portable and reproducible containers. |
| **Automation**     | Make                   | The `Makefile` provides a simple and effective way to orchestrate the various development, deployment, and testing tasks, creating a clear workflow for managing the project lifecycle. |
