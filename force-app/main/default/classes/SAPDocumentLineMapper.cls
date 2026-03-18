/**
 * @description       : Centraliza o mapeamento de campos Kit_Instalacao__c → campos SAP DocumentLine. Elimina duplicação das chains ternárias espalhadas em PedidoCompra,
 *                       PedidoVenda e Contrato. Adicionar novo valor de picklist = editar apenas esta classe.
 * @author            : Daniel Belini
 * @group             : SAP Integration
 * @last modified on  : 03-17-2026
 * @last modified by  : Daniel Belini
 * @test              : IntegracaoSAPCoverageTest, SAPDocumentLineMapperTest
 **/
public with sharing class SAPDocumentLineMapper {
  /**
   * @description Mapeia UnidadeMedidaLocacao__c para o código SAP U_UnitMeasureHired.
   */
  public static String getMeasureUnitId(String unidadeMedida) {
    if (unidadeMedida == null)
      return 'SV';
    if (unidadeMedida.equalsIgnoreCase('Metro'))
      return 'm';
    if (unidadeMedida.equalsIgnoreCase('Metro Quadrados'))
      return 'm2';
    if (unidadeMedida.equalsIgnoreCase('Kilograma'))
      return 'kg';
    if (unidadeMedida.equalsIgnoreCase('Segundos'))
      return 's';
    if (unidadeMedida.equalsIgnoreCase('Horas'))
      return 'h';
    if (unidadeMedida.equalsIgnoreCase('Dia'))
      return 'd';
    if (unidadeMedida.equalsIgnoreCase('Unidade'))
      return 'UN';
    if (unidadeMedida.equalsIgnoreCase('Serviço'))
      return 'SV';
    return 'SV';
  }

  /**
   * @description Mapeia TipoMedicao__c para o código SAP U_MeasurementById.
   */
  public static Integer getMeasurementById(String tipoMedicao) {
    if (tipoMedicao == null)
      return 3;
    if (tipoMedicao.equalsIgnoreCase('Valor'))
      return 1;
    if (tipoMedicao.equalsIgnoreCase('Percentual'))
      return 2;
    return 3;
  }

  /**
   * @description Mapeia TipoFaturamento__c para o código SAP U_BillingType.
   */
  public static Integer getBillingType(String tipoFaturamento) {
    if (tipoFaturamento == null)
      return 5;
    if (tipoFaturamento.equalsIgnoreCase('Nenhum'))
      return 0;
    if (tipoFaturamento.equalsIgnoreCase('Medição'))
      return 1;
    if (tipoFaturamento.equalsIgnoreCase('Parcelado'))
      return 2;
    if (tipoFaturamento.equalsIgnoreCase('Recorrente'))
      return 3;
    if (tipoFaturamento.equalsIgnoreCase('Calculado'))
      return 4;
    if (tipoFaturamento.equalsIgnoreCase('Parcelado Medido'))
      return 5;
    return 5;
  }

  /**
   * @description Mapeia Recorrencia__c para o código SAP U_RecurrenceType.
   *              Utilizado por PedidoCompra e PedidoVenda (Contrato não tem recorrência).
   */
  public static Integer getRecurrenceType(String recorrencia) {
    if (recorrencia == null)
      return 6;
    if (recorrencia.equalsIgnoreCase('Indefinida'))
      return 0;
    if (recorrencia.equalsIgnoreCase('Não se aplica'))
      return 1;
    if (recorrencia.equalsIgnoreCase('Mensal'))
      return 2;
    if (recorrencia.equalsIgnoreCase('Anual'))
      return 3;
    if (recorrencia.equalsIgnoreCase('Bimestral'))
      return 4;
    if (recorrencia.equalsIgnoreCase('Trimestral'))
      return 5;
    if (recorrencia.equalsIgnoreCase('Semestral'))
      return 6;
    return 6;
  }

  /**
   * @description Mapeia Classificacao__c para o código SAP U_Classification.
   *              Utilizado por PedidoCompra (PedidoVenda usa fixo = 7 por decisão de negócio).
   */
  public static Integer getClassification(String classificacao) {
    if (classificacao == null)
      return 7;
    if (classificacao.equalsIgnoreCase('Contratos de Locação'))
      return 1;
    if (classificacao.equalsIgnoreCase('Contratos de Serviços'))
      return 2;
    if (classificacao.equalsIgnoreCase('Contratos de Licenciamento'))
      return 3;
    if (classificacao.equalsIgnoreCase('Compras de equipamentos e materiais'))
      return 4;
    if (classificacao.equalsIgnoreCase('Arrendamento de área rural'))
      return 5;
    if (classificacao.equalsIgnoreCase('Prestação de Serviços (v)'))
      return 6;
    if (classificacao.equalsIgnoreCase('Venda de equipamentos e materiais'))
      return 7;
    return 7;
  }
}
