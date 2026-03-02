public class VOTokenResponse {
  public String access_token;
  public String token_type;
  public Integer expires_in;

  public static VOTokenResponse parse(String json) {
    return (VOTokenResponse) System.JSON.deserialize(
      json,
      VOTokenResponse.class
    );
  }
}
