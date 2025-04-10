import ballerina/http;
import ballerina/io;

public function main() returns error? {
    http:Client logisticsClient = check new ("http://localhost:8080");

    // Create a sample delivery request
    json deliveryRequest = {
        "deliveryType": "express",
        "pickupLocation": "123 Main St, City A",
        "deliveryLocation": "456 Oak St, City B",
        "preferredTimeSlots": ["2023-05-15T10:00:00Z", "2023-05-15T14:00:00Z"],
        "customerInfo": {
            "firstName": "John",
            "lastName": "Doe",
            "contactNumber": "+1234567890"
        }
    };

    // Send the delivery request
    json response = check logisticsClient->/logistics/request.post(deliveryRequest);
    io:println("Delivery request response: ", response.toJsonString());

    // Extract the tracking ID from the response
    string trackingId = check response.trackingId;

    // Check the status of the delivery
    json statusResponse = check logisticsClient->/logistics/status/[trackingId].get();
    io:println("Delivery status: ", statusResponse.toJsonString());
}