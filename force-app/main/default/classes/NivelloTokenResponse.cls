/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : UtilsTest
 **/
public class NivelloTokenResponse {
  public Boolean success;
  public ResponseData data;

  public static NivelloTokenResponse parse(String json) {
    return (NivelloTokenResponse) System.JSON.deserialize(
      json,
      NivelloTokenResponse.class
    );
  }

  public class ResponseData {
    public String token;
    public String refreshToken;
  }
}
