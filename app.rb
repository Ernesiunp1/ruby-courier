require './exchange_rate'
require 'bundler/setup'
Bundler.require


AEROBOX_URLS = %w[http://aerobox.com.ar http://www.aerobox.com.ar https://aerobox.com.ar https://www.aerobox.com.ar http://aerocargo.com.ar https://aerocargo.com.ar]
DELMUNDO_URLS = %w[http://delmundocourier.com https://delmundocourier.com]
origin = (AEROBOX_URLS + DELMUNDO_URLS).join("\s")

set :allow_origin, origin
set :allow_methods, "GET,HEAD,POST"
set :allow_headers, "content-type,if-modified-since"
set :expose_headers, "location,link"

get '/' do
  "Recibi el GET : #{params}".to_json
end

post '/' do
  "Recibi el POST : #{params}".to_json
end

get '/usd_to_ars' do
  dolares = params[:usd]

  if (exchange_rate = ExchangeRate.where(currency: 'USD')
                                  .where(name: 'Turista').first)
    value = exchange_rate.get_value
    time = exchange_rate.time.in_time_zone('America/Argentina/Buenos_Aires')
    quote = (dolares.to_f * value.to_f).round(2)
    {
      currency: exchange_rate.currency,
      name: exchange_rate.name,
      value: value,
      time: time,
      quote: quote,
      quote_display: Money.new(quote * 100, 'ARS').format
    }.to_json
  else
    { error: 'currency' }.to_json
  end
end

get '/fedex_rates' do
  puts "*************************************"
  puts params.inspect
  puts "*************************************"

  client = params[:client]
  shipper_country_code = params[:shipper_country_code]
  shipper_postal_code = postal_code_sanitizer(params[:shipper_postal_code])
  recipient_country_code = params[:recipient_country_code]
  recipient_postal_code = postal_code_sanitizer(params[:recipient_postal_code])
  customs_type = params[:customs_type]
  customs_value = params[:customs_value]
  customs_value_currency = params[:customs_value_currency]
  paquetes = params[:packages]

  parametros_msg = "CLIENT:#{client}\n"  
  parametros_msg += "-ORIGEN-\n"
  parametros_msg += "PAIS:#{shipper_country_code} CP:#{shipper_postal_code}\n"
  parametros_msg += "-DESTINO-\n"
  parametros_msg += "PAIS:#{recipient_country_code} CP:#{recipient_postal_code} VALUE:#{customs_value}#{customs_value_currency} TYPE:#{customs_type} PAQUETES:"
  paquetes.each do |k, package|
    parametros_msg += "\nKG:#{package[:weight_value]} DIM:#{package[:dimensions_length]}x#{package[:dimensions_width]}x#{package[:dimensions_height]}#{package[:dimensions_units]}"
  end

  resultado = {}
  begin
    resultado[:status] = 'success'
    resultado[:tp] = 1
    resultado[:msg] = "Se obtuvieron los costos para #{parametros_msg}"
    resultado[:result] = cotizar_fedex(params)

  rescue => e
    resultado[:status] = 'error'
    resultado[:tp] = 2
    resultado[:msg] = "ERROR: #{e}
                       PARAMS: #{parametros_msg}"
    resultado[:result] = []
  end

  resultado.to_json
end

def cotizar_fedex params={}
  client = params[:client]
  shipper_country_code = params[:shipper_country_code]
  shipper_postal_code = postal_code_sanitizer(params[:shipper_postal_code])
  recipient_country_code = params[:recipient_country_code]
  recipient_postal_code = postal_code_sanitizer(params[:recipient_postal_code])
  customs_type = params[:customs_type]
  customs_value = params[:customs_value]
  customs_value_currency = params[:customs_value_currency]
  paquetes = params[:packages]

  case client
  when 'AEROBOX'
    # TEST
    # fedex = Fedex::Shipment.new(:key => 'DG3OrxytnKCZFXnk', # Developer Test Key
    #                             :password => '43kk2TKmLvlNj5NXXXpvvEfzZ',
    #                             :account_number => '510087500', # Test Account Number
    #                             :meter => '119118230', # Test Meter Number
    #                             :mode => 'development')
    # PROD
    fedex = Fedex::Shipment.new(:key => 'YgTkRxCG9dho9xw2',
      :password => 'liI4NGU8AhHuGrCoPksUPWVaw',
      :account_number => '980587053',
      :meter => '114438358',
      :mode => 'production')

  when 'DELMUNDO'
    # TEST
    # fedex = Fedex::Shipment.new(:key => 'bDHsNYxuttfuCOGW', # Developer Test Key
    #                             :password => 'u4zqFSUIDeb3oIRSeUTVI22yS',
    #                             :account_number => '510087780', # Test Account Number
    #                             :meter => '114035101', # Test Meter Number
    #                             :mode => 'development')
    # PROD
    fedex = Fedex::Shipment.new(:key => 'HJTZ4C7ViK4sI26a',
      :password => 'n2dGeoPdcMgObKAn42helqTpn',
      :account_number => '687809076',
      :meter => '250881317',
      :mode => 'production')
  end

  # Se envia desde:
  shipper = { :postal_code => shipper_postal_code,
              :country_code => shipper_country_code }

  # shipper = { :name => "Sender",
  #   :company => "Company",
  #   :phone_number => "555-555-5555",
  #   :address => "Main Street",
  #   :city => "Harrison",
  #   :state => "AR",
  #   :postal_code => "72601",
  #   :country_code => "US" }

  # Se recibe en:
  recipient = { :postal_code => recipient_postal_code,
                :country_code => recipient_country_code,
                :residential => "false" }

  # recipient = { :name => "Recipient",
  #               :company => "Company",
  #               :phone_number => "555-555-5555",
  #               :address => "Main Street",
  #               :city => "Franklin Park",
  #               :state => "IL",
  #               :postal_code => "60131",
  #               :country_code => "US",
  #               :residential => "false" }

  packages = []
  paquetes.each do |k, package|
    packages << {
      :weight => {:units => "KG", :value => package[:weight_value]},
      :dimensions => {:length => package[:dimensions_length].to_i,
                      :width => package[:dimensions_width].to_i,
                      :height => package[:dimensions_height].to_i,
                      :units => package[:dimensions_units].to_s }
    }
  end

  shipping_options = {
    :packaging_type => "YOUR_PACKAGING",
    :drop_off_type => "REGULAR_PICKUP"
  }

  customs = {
    :document_content => customs_type,
    :customs_value => {
      :currency => customs_value_currency,
      :amount => customs_value.to_i
    }
  }

  if ENV['DEBUG']
    puts '**********************************'
    hash = {shipper: shipper,
            recipient: recipient,
            packages: packages,
            service_type: "INTERNATIONAL_ECONOMY",
            shipping_options: shipping_options,
            customs_clearance_detail: customs}
    puts hash
    puts '**********************************'
  end

  # "INTERNATIONAL_ECONOMY"
  rate = fedex.rate(shipper: shipper,
                    recipient: recipient,
                    packages: packages,
                    service_type: "INTERNATIONAL_ECONOMY",
                    shipping_options: shipping_options,
                    customs_clearance_detail: customs)

  international_economy = rate.first&.total_net_charge

  # "INTERNATIONAL_PRIORITY"
  rate = fedex.rate(shipper: shipper,
                    recipient: recipient,
                    packages: packages,
                    service_type: "INTERNATIONAL_PRIORITY",
                    shipping_options: shipping_options,
                    customs_clearance_detail: customs)

  international_priority = rate.first&.total_net_charge

  return [international_priority, international_economy]
end

def postal_code_sanitizer(postal_code)
  postal_code.to_s.gsub('-','')
end

# options: {
#   :shipper => shipper,
#   :recipient => recipient,
#   :packages => packages,
#   :service_type => "INTERNATIONAL_PRIORITY",
#   :shipping_details => shipping_options,
#   :customs_clearance_detail => customs,
#   :shipping_document => document,
#   :filenames => filenames
# }
#
# customs: {
#   :duties_payment => {
#     :payment_type => 'SENDER',
#     :payor => {
#       :responsible_party => {
#         :account_number => fedex_credentials[:account_number],
#         :contact => {
#           :person_name => 'Mr. Test',
#           :phone_number => '12345678'
#         }
#       }
#     }
#   },
#   :document_content => 'NON_DOCUMENTS',
#   :customs_value => {
#     :currency => 'UKL', # UK Pounds Sterling
#     :amount => 155.79
#   },
#   :commercial_invoice => {
#     :terms_of_sale => 'DDU'
#   },
#   :commodities => [
#     {
#       :number_of_pieces => 1,
#       :description => 'Pink Toy',
#       :country_of_manufacture => 'GB',
#       :weight => {
#         :units => 'LB',
#         :value => 2
#       },
#       :quantity => 1,
#       :quantity_units => 'EA',
#       :unit_price => {
#         :currency => 'UKL',
#         :amount => 155.79
#       },
#       :customs_value => {
#         :currency => 'UKL', # UK Pounds Sterling
#         :amount => 155.79
#       }
#     }
#   ]
# }
