/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 10-09-2025
 * @last modified by	 : Daniel Belini
 **/
global with sharing class OpportunityRecordsTO {
  public class Opportunities {
    public SingleOpportunity[] SingleOpportunity;
  }

  public class SingleOpportunity {
    public String Id;
    public String PartnerProposalId;
    public String PartnerName;
    public String SellerId;
    public String Origem;
    public Double ConsumptionAverage;
    public Double TargetConsume;
    public Double PercentageIncreaseInConsumption;
    public String PowerDistributionCompany;
    public String ZipCode;
    public Double MaxPowerSystem;
    public Integer QuantityModules;
    public String DynamicTechnicalProposal;
    public String SaleType;
    public Product[] Products;
    public Client Client;
    public String RecordTypeId;
    public String StageName;
    public Date CloseDate;
    public Double FinancialCostWeg;
    public Double Direct;
    public Double Rede;
    public Double Pontos;
    public Double Installation;
    public Double AdditionalFixedCost;
    public Double Coupling;
    public Double Bdi;
    public Boolean isPromotional;
    public String GrupoTarifario;
    public Decimal EconomiaAnualEstimada;
    public String PropostaRevo;
    public String AccountId;
    public String LeadId;

    public String fullNameOfResponsible;
    public String positionOfResponsible;
    public String phoneOfResponsible;
    public String emailOfResponsible;
    //public Boolean energyInvoice;
    public Boolean invoiceForLastTwoMonths;
    public Boolean clientHasICMSIncentive;
    public String specialSituation;
    public Boolean clientHasGenerator;
    public Double generatedVolume;
    public Double monthlyAmount;

    public String observacoes;
    public String ConsumerUnit;
    public Decimal LastInvoiceAmount;
    public String Partner;
    public String Status;
    public String SubTipo;
    public Boolean ProdutoSolar;
    public Datetime AppointmentDateTime;
  }

  public class Product {
    public String Id;
    public String Name;
    public Double UnitaryValue;
    public Integer Quantity;
    public String Description;
    public Double UnitaryValueMaxModules;
    public Double FinancialCostWeg;
    public Double Direct;
    public Double Rede;
    public Double Pontos;
    public Double Installation;
    public Double AdditionalFixedCost;
    public Double Coupling;
    public Double Bdi;
  }

  public class Client {
    public String Id;
    public Integer UserType;
    public String Name;
    public String LastName;
    public String FullName;
    public String CorporateName;
    public String Email;
    public String Document;
    public String CellPhone;
    public String RegisterDate;
    public String ModifiedDate;
    public String Procurator;
    public String ProcuratorPhone;
    public String ProcuratorEmail;
    public String ProcuratorRegisterNumber;
    public String RecordTypeId;
    public String BillingCity;
    public String BillingStreet;
    public String BillingCountry;
    public String BillingState;
    public String BillingPostalCode;
    public String District;
    public String AddressNumber;
    public String CEP;
    public String Complemento;
    public String AccountNumber;
  }
}
