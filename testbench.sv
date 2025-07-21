`include "uvm_macros.svh"
import uvm_pkg::*;

// 1. Transaction - Đóng gói dữ liệu
class adder_trans extends uvm_sequence_item;

  rand bit [3:0] a, b;
  bit [4:0] expected_sum;// chứa giá trị  về từ DUT

  `uvm_object_utils(adder_trans) // Macro đăng ký class với UVM factory => ::type_id::create()

  function new(string name = "adder_trans");
    super.new(name);
  endfunction
  
  function void do_print(uvm_printer printer);  
    printer.print_field_int("a", a, 4, UVM_DEC);
    printer.print_field_int("b", b, 4, UVM_DEC);
    printer.print_field_int("expected_sum", expected_sum, 5, UVM_DEC);
  endfunction
endclass

// 2. Driver - chuyển trans thành các tín hiệu pin_in
class adder_driver extends uvm_driver #(adder_trans);
  virtual adder_if vif;

  `uvm_component_utils(adder_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual adder_if)::get(this, "", "vif", vif))
      `uvm_fatal("DRV", "No virtual interface bound")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      adder_trans tr;
      seq_item_port.get_next_item(tr);

      vif.a <= tr.a;
      vif.b <= tr.b;

      // Đợi một delta cycle
      #1;
      tr.expected_sum = vif.sum;

      seq_item_port.item_done();
    end
  endtask
endclass

// 3. Monitor
class adder_monitor extends uvm_monitor;
  virtual adder_if vif;

  `uvm_component_utils(adder_monitor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual adder_if)::get(this, "", "vif", vif))
      `uvm_fatal("MON", "No virtual interface bound")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      #1;
      `uvm_info("MONITOR", $sformatf("a=%0d, b=%0d, sum=%0d", vif.a, vif.b, vif.sum), UVM_LOW)
    end
  endtask
endclass

// 4. Sequence
class adder_sequence extends uvm_sequence #(adder_trans);
  `uvm_object_utils(adder_sequence)

  function new(string name = "adder_sequence");
    super.new(name);
  endfunction

  task body();
    repeat (5) begin
      adder_trans tr = adder_trans::type_id::create("tr");
      assert(tr.randomize());
      start_item(tr);
      finish_item(tr);
    end
  endtask
endclass

// 5. Agent
class adder_agent extends uvm_agent;
  adder_driver   drv;
  adder_monitor  mon;
  uvm_sequencer #(adder_trans) seqr;

  `uvm_component_utils(adder_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    drv  = adder_driver::type_id::create("drv", this);
    mon  = adder_monitor::type_id::create("mon", this);
    seqr = uvm_sequencer #(adder_trans)::type_id::create("seqr", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction
endclass

// 6. Environment
class adder_env extends uvm_env;
  adder_agent agent;

  `uvm_component_utils(adder_env)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    agent = adder_agent::type_id::create("agent", this);
  endfunction
endclass

// 7. Test
class adder_test extends uvm_test;
  adder_env env;
  adder_sequence seq;

  `uvm_component_utils(adder_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    env = adder_env::type_id::create("env", this);
    seq = adder_sequence::type_id::create("seq");
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    seq.start(env.agent.seqr);
    phase.drop_objection(this);
  endtask
endclass

// 8. Interface
interface adder_if;
  logic [3:0] a, b;
  logic [4:0] sum;
endinterface

// 9. Top module
module tb;
  adder_if vif();

  adder4 dut (
    .a(vif.a),
    .b(vif.b),
    .sum(vif.sum)
  );

  initial begin
    uvm_config_db#(virtual adder_if)::set(null, "*", "vif", vif);
    run_test("adder_test");
  end
endmodule
