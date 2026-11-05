import ballerina/http;
import ballerina/os;

// The Products API, wherever it's hosted. On WSO2 Cloud both values come from the
// products-catalog-api Resource that workload.yaml declares, so nobody sets them on the component.
final string productsApiUrl = envOr("PRODUCTS_API_URL", "http://localhost:8080/api/v1");

// Sent as X-API-Key on every call, for an API or gateway that checks API keys.
final readonly & map<string> apiHeaders = apiKeyHeaders();

final http:Client productsApi = check new (productsApiUrl, httpVersion = http:HTTP_1_1);

isolated function apiKeyHeaders() returns readonly & map<string> {
    string apiKey = os:getEnv("PRODUCTS_API_KEY");
    return apiKey == "" ? {} : {"X-API-Key": apiKey};
}

isolated function envOr(string name, string default) returns string {
    string value = os:getEnv(name);
    return value == "" ? default : value;
}
