
class ExchangeRate < ActiveRecord::Base
  def get_value
    # Update cada una hora
    return value.to_f if (Time.now - self.time) <= 3600

    update_value
  end

  def update_value
    # OpenExchangeRates trae el promedio comprador/vendedor
    # APP_ID = '0e65f2d165184946bc05eaeb1febf92e'
    # response = HTTParty.get("https://openexchangerates.org/api/latest.json?base=USD&symbols=ARS&app_id=#{APP_ID}")

    # https://wanderlust.codes/dolar-hoy/demo-call.php
    # https://www.dolarsi.com/api/api.php?type=valoresprincipales
    # https://www.dolarsi.com/api/api.php?type=dolar
    # Usar Banco Nacion Billete - venta + 1.30
    response = HTTParty.get('https://www.dolarsi.com/api/api.php?type=dolar')
    return unless response.code == 200

    json = JSON.parse(response.body)
    return unless (banco_nacion_billete = json.detect { |h|
      h['casa']['nombre'] == 'Banco Nación Billete'
    })

    return unless (venta = banco_nacion_billete['casa']['venta'])

    venta = venta.tr(',', '.').to_f
    # 30% impuesto PAIS
    self.value = (venta * 1.30).round(2).to_f
    self.time = Time.now
    # Grabar
    save

    value.to_f
  end
end
