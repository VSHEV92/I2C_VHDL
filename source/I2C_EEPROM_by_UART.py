import serial
import time


# запись байта в eeprom
def write_byte_to_eeprom (char, address, serial_port):
    id_byte = bytes([160])    # байт идентификации
    dummy_byte = bytes([0])   # байт необходимый для заполнения, любое значение
    wr_add_byte = bytes([1])  # флаг записи адреса
    wr_last_byte = bytes([5])  # флаг записи последнего байта
    address_msb = address // 256               # перевод адреса в байты
    address_lsb = address - address_msb * 256
    address_msb_byte = bytes([address_msb])
    address_lsb_byte = bytes([address_lsb])
    # идентификация устройства
    serial_port.write(dummy_byte)
    serial_port.write(id_byte)
    # адрес записи
    serial_port.write(wr_add_byte)
    serial_port.write(address_msb_byte)
    serial_port.write(wr_add_byte)
    serial_port.write(address_lsb_byte)
    # данные
    serial_port.write(wr_last_byte)
    serial_port.write(bytes(char, 'ascii'))


# запись строки в EEPROM
def write_str_to_eeprom (data_string, address, serial_port):
    # проверка на выход за пределы пространства адресов
    if address + len(data_string) - 1 >= 4096:
        print('Address out of range!')
        return
    else:
        serial_port.open()
        byte_address = address
        for char in data_string:
            write_byte_to_eeprom(char, byte_address, serial_port)  # записываем данные по байту
            byte_address += 1
        serial_port.close()
        print('Press Button', len(data_string), 'time, then press Enter', end='')
        input()
        print('Write Done')


# чтение строки из EEPROM
def read_str_from_eeprom (address, number_of_bytes, serial_port):
    id_add_byte = bytes([160])  # байт идентификации для записи адреса
    id_rw_byte = bytes([161])  # байт идентификации для чтения
    dummy_byte = bytes([0])  # байт необходимый для заполнения, любое значение
    wr_add_byte = bytes([1])  # флаг записи адреса
    rd_data_byte = bytes([2])  # флаг чтения байта
    rd_last_byte = bytes([4])  # флаг чтения последнего байта

    # проверка на выход за пределы пространства адресов
    if address + number_of_bytes - 1 >= 4096:
        print('Address out of range!')
        return
    else:
        address_msb = address // 256  # перевод адреса в байты
        address_lsb = address - address_msb * 256
        address_msb_byte = bytes([address_msb])
        address_lsb_byte = bytes([address_lsb])

        serial_port.open()
        # идентификация устройства для записи адреса
        serial_port.write(dummy_byte)
        serial_port.write(id_add_byte)
        # адрес записи
        serial_port.write(wr_add_byte)
        serial_port.write(address_msb_byte)
        serial_port.write(wr_add_byte)
        serial_port.write(address_lsb_byte)
        # идентификация устройства для чтения
        serial_port.write(dummy_byte)
        serial_port.write(id_rw_byte)
        # запросы на чтение байтов
        for idx in range(number_of_bytes-1):
            serial_port.write(rd_data_byte)
            serial_port.write(dummy_byte)
        # запросы на чтение последнего байта
        serial_port.write(rd_last_byte)
        serial_port.write(dummy_byte)

        print('Press Button to start read')
        rx_string = ''
        # считывание данных из памяти
        for idx in range(number_of_bytes):
            char = serial_port.read().decode("ascii")
            rx_string = rx_string + char
        serial_port.close()
        print('Read Done')
        return rx_string


# инициализация последовательного порта
serial_port = serial.Serial()
serial_port.port = '/dev/ttyUSB0'
serial_port.baudrate = 9600
serial_port.bytesize = 8
serial_port.parity = 'N'
serial_port.stopbits = 1

# запись данных
tx_string = 'Hello!'

address_wr = 104
write_str_to_eeprom(tx_string, address_wr, serial_port)

# чтение данных
print('Press Enter then Button to read data', end='')
input()

address_rd = 104
number_of_bytes = len(tx_string)
rx_string = read_str_from_eeprom(address_rd, number_of_bytes, serial_port)
print('Rx_String is "' + rx_string + '"')
