public class NivelloTokenResponse {

    public Boolean      success;
    public ResponseData data;

    public static NivelloTokenResponse parse(String json) {
        return (NivelloTokenResponse) System.JSON.deserialize(json, NivelloTokenResponse.class);
    }

    public class ResponseData {
        public String token;
        public String refreshToken;
    }
}