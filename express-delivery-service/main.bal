import ballerina/http;
import ballerinax/mongodb;
import ballerinax/kafka;
import ballerina/time;
import ballerina/log;
import ballerina/lang.runtime;

configurable mongodb:ConnectionConfig mongodbUri = ?; 
configurable string kafkaBootstrapServers = ?;

type DeliveryRequest record {
    string deliveryType;
    string pickupLocation;
    string deliveryLocation;
    string[] preferredTimeSlots;
    CustomerInfo customerInfo;
};

type CustomerInfo record {
    string firstName;
    string lastName;
    string contactNumber;
};

type DeliveryResponse record {
    string trackingId;
    string status;
    string estimatedDeliveryTime;
    DeliveryRequest originalRequest;
};

service /express on new http:Listener(8081) {
    private final mongodb:Client mongoClient;

    function init() returns error? {
        self.mongoClient = check new (mongodbUri);
        log:printInfo("Express Delivery Service initialized");
    }

    resource function get deliveries() returns DeliveryResponse[]|error {
        stream<DeliveryResponse, error?> result = check self.mongoClient->find("expressDeliveries");
        return from DeliveryResponse delivery in result
            select delivery;
    }
}

service on new kafka:Listener(kafkaBootstrapServers, {
    groupId: "express-delivery-group",
    topics: ["expressDeliveryTopic"]
}) {
    private final mongodb:Client mongoClient;
    private final kafka:Producer kafkaProducer;

    function init() returns error? {
        self.mongoClient = check new (mongodbUri);

        kafka:ProducerConfiguration producerConfig = {
            clientId: "express-delivery-producer",
            acks: "all",
            retryCount: 3
        };
        self.kafkaProducer = check new (kafkaBootstrapServers, producerConfig);
    }

    remote function onConsumerRecord(kafka:ConsumerRecord[] records) returns error? {
        foreach kafka:ConsumerRecord record in records{
            DeliveryResponse response = check record.value.fromBytes().fromJsonString().cloneWithType();
            DeliveryResponse updatedResponse = check self.processExpressDelivery(response);
            
            // Store in MongoDB
            _ = check self.mongoClient->insert(updatedResponse, "expressDeliveries");
            
            // Send response back to central logistics service
            byte[] serializedMsg = updatedResponse.toJsonString().toBytes();
            _ = check self.kafkaProducer->send({topic: "expressDeliveryResponseTopic", value: serializedMsg});

            log:printInfo(string `Processed express delivery for tracking ID: ${updatedResponse.trackingId}`);
        }
    }

    function processExpressDelivery(DeliveryResponse response) returns DeliveryResponse|error {
        // Simulate processing time
        runtime:sleep(1);

        time:Utc currentTime = time:utcNow();
        time:Utc estimatedDeliveryTime = time:utcAddSeconds(currentTime, 172800); // 2 days

        response.status = "Processing Express Delivery";
        response.estimatedDeliveryTime = time:utcToString(estimatedDeliveryTime);
        return response;
    }
}