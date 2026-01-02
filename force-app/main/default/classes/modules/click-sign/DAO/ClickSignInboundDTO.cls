public class ClickSignInboundDTO {

    public Event event { get; set; }
    public Document document { get; set; }
    public Template template { get; set; }
    public List<Signer> signers { get; set; }
    public List<EventDetail> events { get; set; }

    public class Event {
        public String name { get; set; }
        public Data data { get; set; }
        public Datetime occurred_at { get; set; }
    }

    public class Data {
        public Signer signer;
    }

    public class Document {
        public String key { get; set; }
        public String account_key { get; set; }
        public String path { get; set; }
        public String filename { get; set; }
        public Datetime uploaded_at { get; set; }
        public Datetime updated_at { get; set; }
        public Datetime finished_at { get; set; }
        public Datetime deadline_at { get; set; }
        public String status { get; set; }
        public Boolean auto_close { get; set; }
        public String locale { get; set; }
        public Map<String, Object> metadata { get; set; }
        public Boolean sequence_enabled { get; set; }
        public Integer remind_interval { get; set; }
        public Boolean block_after_refusal { get; set; }
        public Boolean preview { get; set; }
        public Downloads downloads { get; set; }
    }

    public class Downloads {
        public String original_file_url { get; set; }
        public String signed_file_url { get; set; }
        public String signed_file_checksum { get; set; }
        public String ziped_file_url { get; set; }
    }

    public class Template {
        public Object data { get; set; }
    }

    public class EventDetail {
        public String name { get; set; }
        public Object data { get; set; }
        public Datetime occurred_at { get; set; }
    }

    public class Signer {
        public String sign_as { get; set; }
        public String list_key { get; set; }
        public String key { get; set; }
        public String email { get; set; }
        public String name { get; set; }
        public String birthday { get; set; }
        public Datetime created_at { get; set; }
        public String documentation { get; set; }
        public Boolean has_documentation { get; set; }
        public List<String> auths { get; set; }
        public Boolean selfie_enabled { get; set; }
        public Boolean handwritten_enabled { get; set; }
        public Boolean official_document_enabled { get; set; }
        public Boolean liveness_enabled { get; set; }
        public Boolean facial_biometrics_enabled { get; set; }
        public String communicate_by { get; set; }
        public String phone_number { get; set; }
        public String phone_number_hash { get; set; }
        public String url { get; set; }
        public String address { get; set; }
        public String longitude { get; set; }
        public String latitude { get; set; }
    }
}