import ballerina/http;
import ballerinax/mongodb;
import ballerinax/kafka;
import ballerina/uuid;
import ballerina/log;
import ballerina/time;

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

service /logistics on new http:Listener(8080) {
    private final mongodb:Client mongoClient;
    private final kafka:Producer kafkaProducer;

    function init() returns error? {
        self.mongoClient = check new (mongodbUri);

        kafka:ProducerConfiguration producerConfig = {
            clientId: "logistics-producer",
            acks: "all",
            retryCount: 3
        };
        self.kafkaProducer = check new (kafkaBootstrapServers, producerConfig);

        log:printInfo("Central Logistics Service initialized");
    }

    resource function post request(@http:Payload DeliveryRequest payload) returns DeliveryResponse|error {
        string trackingId = uuid:createType1AsString();
        DeliveryResponse response = {
            trackingId: trackingId,
            status: "Processing",
            estimatedDeliveryTime: "TBD",
            originalRequest: payload
        };

        // Store initial request in MongoDB
        check self.storeDeliveryRequest(response);

        // Send to appropriate Kafka topic
        check self.sendToDeliveryService(payload.deliveryType, response);

        log:printInfo(string `Processed delivery request: ${trackingId}`);
        return response;
    }

    resource function get status/[string trackingId]() returns DeliveryResponse|error {
        mongodb:Filter filter = {trackingId: trackingId};
        DeliveryResponse? delivery = check self.mongoClient->findOne("deliveries", filter);

        if delivery is () {
            return error("Tracking ID not found");
        }

        log:printInfo(string `Retrieved status for tracking ID: ${trackingId}`);
        return delivery;
    }

    function storeDeliveryRequest(DeliveryResponse response) returns error? {
        _ = check self.mongoClient->insert(response, "deliveries");
    }

    function sendToDeliveryService(string deliveryType, DeliveryResponse response) returns error? {
        string topic = deliveryType + "DeliveryTopic";
        byte[] serializedMsg = response.toJsonString().toBytes();
        _ = check self.kafkaProducer->send({topic: topic, value: serializedMsg});
    }
}

service on new kafka:Listener(kafkaBootstrapServers, {
    groupId: "logistics-group",
    topics: ["standardDeliveryResponseTopic", "expressDeliveryResponseTopic", "internationalDeliveryResponseTopic"]
}) {
    private final mongodb:Client mongoClient;

    function init() returns error? {
        self.mongoClient = check new (mongodbUri);
    }

    remote function onConsumerRecord(kafka:ConsumerRecord[] records) returns error? {
        foreach kafka:ConsumerRecord record in records {
            DeliveryResponse response = check record.value.fromBytes().fromJsonString().cloneWithType();
            
            mongodb:Filter filter = {trackingId: response.trackingId};
            _ = check self.mongoClient->update("deliveries", filter, response);

            log:printInfo(string `Updated delivery status for tracking ID: ${response.trackingId}`);
        }
    }
}