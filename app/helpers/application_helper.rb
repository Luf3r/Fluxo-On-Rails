module ApplicationHelper
  def finance_money(amount, currency = "BRL")
    unit = { "BRL" => "R$ ", "USD" => "$ ", "EUR" => "€ " }.fetch(currency, "#{currency} ")
    number_to_currency(amount, unit: unit, **finance_number_format)
  end

  def finance_number_format
    return { separator: ",", delimiter: "." } if I18n.locale == :"pt-BR"

    { separator: ".", delimiter: "," }
  end
end
