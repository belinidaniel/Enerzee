public with sharing class ClickSignResponseDTO {
    
    /*DTO de response da chamada de envio de Envelopes*/
    public class Envelope {
        public Envelope() {}
        public EnvelopeData data;
    }

    public class EnvelopeData {
        public String id;
        public String type;
        public Links links;
        public EnvelopeAttributes attributes;
        public EnvelopeRelationships relationships;
    }

    public class EnvelopeAttributes {
        public String name;
        public String status;
        public String deadline_at;
        public String locale;
        public Boolean auto_close;
        public Integer remind_interval;
        public Boolean block_after_refusal;
        public String created;
        public String modified;
    }

    public class EnvelopeRelationships {
        public EnvelopeDocuments documents;
        public EnvelopeSigners signers;
        public EnvelopeRequirements requirements;
    }

    public class EnvelopeDocuments {
        public Links links;
    }

    public class EnvelopeSigners {
        public Links links;
    }

    public class EnvelopeRequirements {
        public Links links;
    }
    /*Fim da DTO para envio de envelopes.*/

    /*DTO de response da chamada de envio de Documentos*/
    public class Document {
        public DocumentData data;
    }

    public class DocumentData {
        public String id;
        public String type;
        public Links links;
        public DocumentAttributes attributes;
    }

    public class Files {
        public String original;
    }

    public class DocumentAttributes {
        public String status;
        public String filename;
        public String created;
        public String modified;
    }
    /*Fim da DTO para envio de documentos.*/

    /*DTO de response da chamada de envio de Signers*/
    public class Signer {
        public SignerData data;
    }

    public class SignerData {
        public String id;
        public String type;
        public Links links;
        public SignerAttributes attributes;
    }

    public class SignerAttributes {
        public String name;
        public String birthday;
        public String email;
        public String phone_number;
        public Boolean has_documentation;
        public String documentation;
        public Boolean refusable;
        public SignerCommunicateEvents communicate_events;
    }

    public class SignerCommunicateEvents {
        public String document_signed;
        public String signature_request;
        public String signature_reminder;
    }

    /*DTO de response da chamada de envio de Templates*/
    public class Template {
        public TemplateData data;
    }

    public class TemplateData {
        public String id;
        public String type;
        public Links links;
        public TemplateAttributes attributes;
    }

    public class TemplateAttributes {
        public String name;
    }
    /*Fim da DTO para envio de Templates.*/

    /*Generico para todas as DTOs.*/
    public class Links {
        public String self;
        public Files files;
    }

    public class Error {
        public String code;
        public Integer status;
        public Object source;
        public String detail;
    }
}