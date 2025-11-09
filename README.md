# Actividad VII y VIII: Procesador FSMD en Basys 3

Este repositorio contiene un proyecto de FSMD (Máquina de Estados Finita con Datapath) implementado en SystemVerilog para la FPGA Digilent Basys 3. El sistema actúa como un co-procesador de hardware capaz de calcular dos secuencias matemáticas, **Padovan** y **Moser-de Bruijn**, y es controlado a través de dos modos de operación distintos.

El proyecto está dividido en dos versiones:

* **version_1:** Un sistema base controlado exclusivamente por una terminal UART.
* **version_2:** Una versión mejorada que añade control manual a través de los switches de la tarjeta y la muestra visual en el display de 7 segmentos.

## 🛠️ Herramientas
* **Hardware:** Tarjeta FPGA Digilent Basys 3
* **Software:** AMD Vivado 2025.1
* **Lenguaje:** SystemVerilog



##  Versión 1: Control por UART

La Versión 1 implementa el núcleo del sistema. Un `top_controller` gestiona la comunicación con una PC a través de una terminal serie.

### Características
* Comunicación UART (9600 baud, 8-N-1).
* Envía un mensaje de bienvenida al conectarse (`Comando: [P/M] [n, 0-F] [Enter]\r\n`).
* **Recibe comandos** textuales para ejecutar cálculos.
* **Hace eco** de los caracteres recibidos de vuelta a la terminal.
* Formatea el resultado de 32 bits en una cadena hexadecimal (ej. `0x00000003`) y lo envía de vuelta.

### Módulos (V1)
* `top_controller.sv`: La FSMD principal que gestiona los estados del sistema.
* `uart_rx.sv`: Módulo receptor UART (serie a paralelo).
* `uart_tx.sv`: Módulo transmisor UART (paralelo a serie).
* `padovan.sv`: Módulo de cálculo para la secuencia Padovan.
* `moser.sv`: Módulo de cálculo para la secuencia Moser-de Bruijn.

### Cómo Probar (V1)
1.  Sintetizar y cargar el bitstream de la `version_1` en la Basys 3.
2.  Conectar un terminal serie (ej. Tera Term, PuTTY) al puerto COM de la Basys 3 a **9600 baudios**.
3.  Presionar el botón de reset (`clr`).
4.  Escribir `P5` y presionar `Enter`.
5.  **Resultado:** La terminal deberá mostrar el eco "P5" y luego el resultado `"0x00000003"`.
6.  Escribir `M6` y presionar `Enter`.
7.  **Resultado:** La terminal deberá mostrar el eco "M6" y luego el resultado `"0x00000014"`.

---

## 🌟 Versión 2: Mejoras de Hardware (Switches y Display)

La Versión 2 expande el `top_controller` para incluir entradas y salidas de hardware, permitiendo una operación "standalone" sin necesidad de una PC. Mantiene **toda la funcionalidad** de la Versión 1.

### Nuevas Características (V2)
* **Selector de Modo:** `SW15` selecciona la fuente de entrada:
    * `SW15 = 0`: **Modo UART** (funciona igual que la V1).
    * `SW15 = 1`: **Modo Manual**.
* **Entrada Manual:** En Modo Manual, la entrada se lee desde los switches:
    * `SW14`: Selecciona el algoritmo (0 = Padovan, 1 = Moser).
    * `SW[3:0]`: Proporciona el valor de `n` (0 a 15).
    * `BTNR` (Botón Derecho): Actúa como "Enter" para iniciar el cálculo.
* **Salida de Display:** El display de 7 segmentos muestra el estado actual y los resultados:
    * Muestra `"AAAA"` ("----") en estado `IDLE`.
    * Muestra `"bCCC"` ("UArt") cuando está en Modo UART esperando un comando.
    * Muestra el valor de los switches (ej. `"8007"`) cuando está en Modo Manual.
    * Muestra `"FBBB"` ("runn") mientras un cálculo está en progreso.
    * Muestra los 4 dígitos menos significativos del resultado (ej. `"0005"`) cuando el cálculo finaliza.

### Módulos Adicionales (V2)
* `top_controller_v2.sv`: La FSMD actualizada con la lógica de selección de modo.
* `x7segmux_v2.sv`: Controlador del display de 7 segmentos (multiplexor y decodificador Hex-a-7seg).
* `debouncer_v2.sv`: Filtro de "debouncer" para el `BTNR` para asegurar una sola pulsación limpia.

### Cómo Probar (V2)
1.  Sintetizar y cargar el bitstream de la `version_2`.
2.  **Probar Modo UART (SW15 = 0):**
    * Poner `SW15` en la posición de abajo (0).
    * Realizar la misma prueba de la V1 con la terminal serie.
    * **Verificar:** Mientras la terminal muestra `"0x00000003"`, el display de 7 segmentos deberá mostrar **`0003`**.
3.  **Probar Modo Manual (SW15 = 1):**
    * Poner `SW15` en la posición de arriba (1).
    * **Configurar P(7):**
        * Poner `SW14` en bajo (0 para Padovan).
        * Poner `SW[3:0]` en `0111` (para n=7).
        * El display deberá mostrar `"8007"` (reflejando los switches).
    * **Ejecutar:** Presionar el botón `BTNR`.
    * **Verificar:** El display mostrará `"FBBB"` ("runn") brevemente y luego el resultado **`0005`** (ya que P(7) = 5).
