/**
 * @description       : Centralizes BPAddress and BPFiscalTaxID building for all SAP business partner integrations. Eliminates duplicate address construction in IntegracaoSAPCliente,
 *                       Consultor, Fornecedor, Integrador.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-18-2026
 * @last modified by  : Daniel Belini
 * @test              : SAPBusinessPartnerMapperTest
 **/
public with sharing class SAPBusinessPartnerMapper {
  private static final Map<String, String> STATE_ABBREVIATIONS = new Map<String, String>{
    'Acre' => 'AC',
    'Alagoas' => 'AL',
    'Amapá' => 'AP',
    'Amazonas' => 'AM',
    'Bahia' => 'BA',
    'Ceará' => 'CE',
    'Distrito Federal' => 'DF',
    'Espírito Santo' => 'ES',
    'Goiás' => 'GO',
    'Maranhão' => 'MA',
    'Mato Grosso' => 'MT',
    'Mato Grosso do Sul' => 'MS',
    'Minas Gerais' => 'MG',
    'Pará' => 'PA',
    'Paraíba' => 'PB',
    'Paraná' => 'PR',
    'Pernambuco' => 'PE',
    'Piauí' => 'PI',
    'Rio de Janeiro' => 'RJ',
    'Rio Grande do Norte' => 'RN',
    'Rio Grande do Sul' => 'RS',
    'Rondônia' => 'RO',
    'Roraima' => 'RR',
    'Santa Catarina' => 'SC',
    'São Paulo' => 'SP',
    'Sergipe' => 'SE',
    'Tocantins' => 'TO'
  };

  /**
   * Normalizes a state value to its 2-letter abbreviation.
   * Returns the value as-is if already 2 chars or null.
   */
  public static String normalizeState(String state) {
    if (state == null || state.length() == 2) {
      return state;
    }
    return STATE_ABBREVIATIONS.get(state);
  }

  /**
   * Normalizes a country value — converts 'Brasil' to 'BR'.
   * Returns the value as-is for any other input.
   */
  public static String normalizeCountry(String country) {
    if (country == null) {
      return country;
    }
    return country.equalsIgnoreCase('Brasil') ? 'BR' : country;
  }

  /**
   * Builds a billing address (bo_BillTo, RowNum=0).
   */
  public static BPAddress buildBillingAddress(
    String bpCode,
    String street,
    String streetNo,
    String block,
    String zipCode,
    String city,
    String county,
    String country,
    String state,
    String complement
  ) {
    BPAddress addr = new BPAddress();
    addr.AddressName = 'Endereço cobrança';
    addr.AddressType = 'bo_BillTo';
    addr.RowNum = 0;
    addr.BPCode = bpCode;
    addr.Street = street;
    addr.StreetNo = streetNo;
    addr.Block = block;
    addr.ZipCode = zipCode;
    addr.City = city;
    addr.County = county;
    addr.Country = country;
    addr.State = state;
    addr.BuildingFloorRoom = complement != null ? complement : '';
    return addr;
  }

  /**
   * Builds a shipping address (bo_ShipTo, RowNum=1).
   */
  public static BPAddress buildShippingAddress(
    String bpCode,
    String street,
    String streetNo,
    String block,
    String zipCode,
    String city,
    String county,
    String country,
    String state,
    String complement
  ) {
    BPAddress addr = new BPAddress();
    addr.AddressName = 'Endereço entrega';
    addr.AddressType = 'bo_ShipTo';
    addr.RowNum = 1;
    addr.BPCode = bpCode;
    addr.Street = street;
    addr.StreetNo = streetNo;
    addr.Block = block;
    addr.ZipCode = zipCode;
    addr.City = city;
    addr.County = county;
    addr.Country = country;
    addr.State = state;
    addr.BuildingFloorRoom = complement != null ? complement : '';
    return addr;
  }

  /**
   * Builds the fiscal tax ID entry. Uses TaxID0 for CPF holders, TaxID4 for CNPJ holders.
   */
  public static BPFiscalTaxID buildFiscalTaxId(
    String cpf,
    String cnpj,
    String seCPFouCNPJ
  ) {
    BPFiscalTaxID taxId = new BPFiscalTaxID();
    if (cpf != null) {
      taxId.TaxID0 = seCPFouCNPJ;
    } else if (cnpj != null) {
      taxId.TaxID4 = seCPFouCNPJ;
    }
    return taxId;
  }

  public class BPAddress {
    public String AddressName;
    public String Street;
    public String Block;
    public String ZipCode;
    public String City;
    public String County;
    public String Country;
    public String State;
    public String BuildingFloorRoom;
    public String AddressType;
    public String StreetNo;
    public String BPCode;
    public Integer RowNum;
  }

  public class BPFiscalTaxID {
    public String TaxID0;
    public String TaxID4;
  }
}
