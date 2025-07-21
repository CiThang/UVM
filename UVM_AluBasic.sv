`include "uvm_macros.svh"
import uvm_pkg::*;

// 1. Transaction
class alu_trans extends uvm_sequence_item;
    rand bit [3:0] a;
    rand bit [3:0] b;
    rand bit [1:0] sel;
    bit [3:0] result;
    bit carry_out;
    bit zero;

    `uvm_object_utils(alu_trans)

    function new (string name = "alu_trans");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("a=%0b b=%0b | sel=%0b result=%0b carry_out=%0b | zero=0x%0h",
                         a, b, sel, result, carry_out, zero);
    endfunction
endclass

// 2. Driver
class alu_driver extends uvm_driver #(alu_trans);
    virtual alu_if vif;

    `uvm_component_utils(alu_driver)

    function new(string name ="alu_driver", uvm_component parent);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual alu_if)::get(this,"","vif",vif))
            `uvm_fatal("DRV","No virtual interface bound")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            alu_trans tr;
            seq_item_port.get_next_item(tr);

            vif.a <= tr.a;
            vif.b <= tr.b;
            vif.sel <= tr.sel;

            #1; // Wait for result to propagate

            tr.result = vif.result;
            tr.carry_out = vif.carry_out;
            tr.zero = vif.zero;

            `uvm_info("DRIVER", tr.convert2string(), UVM_MEDIUM)

            seq_item_port.item_done();
        end 
    endtask
endclass

// 3. Monitor
class alu_monitor extends uvm_monitor;
    virtual alu_if vif;

    `uvm_component_utils(alu_monitor)

    function new (string name ="alu_monitor",uvm_component parent);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual alu_if)::get(this,"","vif",vif))
            `uvm_fatal("MON","No virtual interface bound")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            #1;
            `uvm_info("MONITOR", 
                      $sformatf("a=%0d, b=%0d, sel=%0d | result=%0d, carry_out=%0b, zero=%0b",
                                vif.a, vif.b, vif.sel, vif.result, vif.carry_out, vif.zero),
                      UVM_LOW)
        end
    endtask
endclass

// 4. Sequence
class alu_sequence extends uvm_sequence#(alu_trans);
    `uvm_object_utils(alu_sequence)

    function new(string name = "alu_sequence");
        super.new(name);
    endfunction

    task body();
        repeat(10) begin
            alu_trans tr = alu_trans::type_id::create("tr");
            assert(tr.randomize());
            start_item(tr);
            finish_item(tr);
        end
    endtask
endclass

// 5. Agent
class alu_agent extends uvm_agent;
    alu_driver drv;
    alu_monitor mon;
    uvm_sequencer#(alu_trans) seqr;

    `uvm_component_utils(alu_agent)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = alu_driver::type_id::create("drv", this);
        mon = alu_monitor::type_id::create("mon", this);
        seqr = uvm_sequencer#(alu_trans)::type_id::create("seqr", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass

// 6. Environment
class alu_env extends uvm_env;
    alu_agent agent;

    `uvm_component_utils(alu_env)

    function new(string name, uvm_component parent);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = alu_agent::type_id::create("agent",this);
    endfunction
endclass

// 7. Test
class alu_test extends uvm_test;
    alu_env env;
    alu_sequence seq;

    `uvm_component_utils(alu_test)

    function new(string name, uvm_component parent);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = alu_env::type_id::create("env",this);
        seq = alu_sequence::type_id::create("seq");
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass

// 8. Interface
interface alu_if;
    logic [3:0] a,b;
    logic [1:0] sel;
    logic [3:0] result;
    logic carry_out,zero;
endinterface

// 9. Top-level testbench
module tb;
    alu_if vif();

    alu dut(
        .a(vif.a),
        .b(vif.b),
        .sel(vif.sel),
        .result(vif.result),
        .carry_out(vif.carry_out),
        .zero(vif.zero)
    );

    initial begin
        uvm_config_db#(virtual alu_if)::set(null, "*", "vif", vif);
        run_test("alu_test");
    end
endmodule
