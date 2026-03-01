public with sharing class ClickSignRequestDTO {
  public ClickSignRequestDTO() {
  }

  /*DTO de request da chamada de envio de Envelopes*/
  public class Envelope {
    public Envelope() {
    }
    public EnvelopeData data;
  }

  public class EnvelopeData {
    public String type_replaced;
    public EnvelopeAttributes attributes;
  }

  public class EnvelopeAttributes {
    public String name;
    public String locale;
    public Boolean auto_close;
    public Integer remind_interval;
    public String deadline_at;
    public String default_subject;
    public String default_message;
  }

  /*DTO de request da chamada de envio de Ativação de Envelopes*/
  public class EnvelopeActivation {
    public EnvelopeActivationData data;
  }

  public class EnvelopeActivationData {
    public String type_replaced;
    public String id;
    public EnvelopeActivationAttributes attributes;
  }

  public class EnvelopeActivationAttributes {
    public String status;
  }

  /*DTO de request da chamada de envio de Documentos*/
  public class Document {
    public DocumentData data;
  }

  public class DocumentData {
    public String type_replaced;
    public DocumentAttributes attributes;
  }

  public class DocumentAttributes {
    public String filename;
    public String content_base64;
  }

  /*DTO de request da chamada de envio de Templates*/
  public class TemplateDocument {
    public TemplateDocumentData data;
  }

  public class TemplateDocumentData {
    public String type_replaced;
    public TemplateDocumentAttributes attributes;
  }

  public class TemplateDocumentAttributes {
    public String filename;
    public TemplateDocumentAttributesTemplate template;
  }

  public class TemplateDocumentAttributesTemplate {
    public String key;
    public Object data;
  }

  /*DTO de request da chamada de envio de Templates*/
  public class Template {
    public TemplateData data;
  }

  public class TemplateData {
    public String type_replaced;
    public TemplateAttributes attributes;
  }

  public class TemplateAttributes {
    public String name;
    public String content_base64;
  }

  /*DTO de request da chamada de envio de Signers*/
  public class Signer {
    public SignerData data;
  }

  public class SignerData {
    public String type_replaced;
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

  /*DTO de request da chamada de envio de Requirements Qualification*/
  public class RequirementQualification {
    public RequirementQualificationData data;
  }

  public class RequirementQualificationData {
    public String type_replaced;
    public RequirementQualificationAttributes attributes;
    public RequirementRelationships relationships;
  }

  public class RequirementQualificationAttributes {
    public String action;
    public String role;
  }

  public class RequirementRelationships {
    public RequirementRelatedData document;
    public RequirementRelatedData signer;
  }

  public class RequirementRelatedData {
    public RequirementDataReference data;
  }

  public class RequirementDataReference {
    public String type_replaced;
    public String id;
  }

  /*DTO de request da chamada de envio de Requirements Autentication*/
  public class RequirementAutentication {
    public RequirementAutenticationData data;
  }

  public class RequirementAutenticationData {
    public String type_replaced;
    public RequirementAutenticationAttributes attributes;
    public RequirementRelationships relationships;
  }

  public class RequirementAutenticationAttributes {
    public String action;
    public String auth;
  }

  /*DTO de request da chamada de envio de Notification*/
  public class EnvelopeNotification {
    public EnvelopeNotificationData data;
  }

  public class EnvelopeNotificationData {
    public String type_replaced;
    public EnvelopeNotificationAttributes attributes;
  }

  public class EnvelopeNotificationAttributes {
    public String message;
  }
}
