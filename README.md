 # Logistics System

This is a distributed logistics system with multiple services for handling different types of deliveries. The system uses Kafka for communication and MongoDB for data storage.

## Services

1. **Central Logistics Service**:
   - Coordinates and delegates shipment requests to the appropriate delivery services (standard, express, international).
   - Listens on port `8080`.

2. **Standard Delivery Service**:
   - Handles standard delivery requests by listening to the `standard-delivery` Kafka topic.

3. **Express Delivery Service**:
   - Handles express delivery requests by listening to the `express-delivery` Kafka topic.

4. **International Delivery Service**:
   - Handles international delivery requests by listening to the `international-delivery` Kafka topic.

## Prerequisites

- Docker
- Docker Compose

## Setup

1. Clone the repository and navigate to the project directory.

2. Build and start all services using Docker Compose:
   ```bash
   docker-compose up --build

