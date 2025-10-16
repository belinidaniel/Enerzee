public class NivelloTokenRequest {
   public String login;	
   public String password;	
    
    
   public static NivelloTokenRequest parse(String json){
		return (NivelloTokenRequest) System.JSON.deserialize(json, NivelloTokenRequest.class);	
   }
}