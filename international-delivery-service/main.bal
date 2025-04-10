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

service /international on new http:Listener(8083) {
    private final mongodb:Client mongoClient;

    function init() returns error? {
        self.mongoClient = check new (mongodbUri);
        log:printInfo("International Delivery Service initialized");
    }

    resource function get deliveries() returns DeliveryResponse[]|error {
        stream<DeliveryResponse, error?> result = check self.mongoClient->find("internationalDeliveries");
        return from DeliveryResponse delivery in result
            select delivery;
    }
}

service on new kafka:Listener(kafkaBootstrapServers, {
    groupId: "international-delivery-group",
    topics: ["internationalDeliveryTopic"]
}) {
    private final mongodb:Client mongoClient;
    private final kafka:Producer kafkaProducer;

    function init() returns error? {
        self.mongoClient = check new (mongodbUri);

        kafka:ProducerConfiguration producerConfig = {
            clientId: "international-delivery-producer",
            acks: "all",
            retryCount: 3
        };
        self.kafkaProducer = check new (kafkaBootstrapServers, producerConfig);
    }

    remote function onConsumerRecord(kafka:ConsumerRecord[] records) returns error? {
        foreach kafka:ConsumerRecord record in records {
            DeliveryResponse response = check record.value.fromBytes().fromJsonString().cloneWithType();
            DeliveryResponse updatedResponse = check self.processInternationalDelivery(response);
            
            // Store in MongoDB
            _ = check self.mongoClient->insert(updatedResponse, "internationalDeliveries");
            
            // Send response back to central logistics service
            byte[] serializedMsg = updatedResponse.toJsonString().toBytes();
            _ = check self.kafkaProducer->send({topic: "internationalDeliveryResponseTopic", value: serializedMsg});

            log:printInfo(string `Processed international delivery for tracking ID: ${updatedResponse.trackingId}`);
        }
    }

    function processInternationalDelivery(DeliveryResponse response) returns DeliveryResponse|error {
        // Simulate processing time
        runtime:sleep(3);

        time:Utc currentTime = time:utcNow();
        time:Utc estimatedDeliveryTime = time:utcAddSeconds(currentTime, 864000); // 10 days

        response.status = "Processing International Delivery";
        response.estimatedDeliveryTime = time:utcToString(estimatedDeliveryTime);
        return response;
    }
}