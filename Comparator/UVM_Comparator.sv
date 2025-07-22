`include "uvm_macros.svh"
import uvm_pkg::*;

//1. Transaction
class comparator_trans extends uvm_sequence_item;

    rand bit [1:0] a,b;
    bit A_gt_B,A_eq_B,A_lt_B;

    `uvm_object_utils(comparator_trans);

    function new (string name = "comparator_trans");
        super.new(name);
    endfunction

    function void do_print(uvm_printer printer);
        printer.print_field_int("a",a,2,UVM_DEC);
        printer.print_field_int("b",b,2,UVM_DEC);   
        printer.print_field_int("A_gt_B",A_gt_B,2,UVM_DEC); 
        printer.print_field_int("A_eq_B",A_eq_B,2,UVM_DEC); 
        printer.print_field_int("A_lt_B",A_lt_B,2,UVM_DEC); 
    endfunction
endclass

//2. Driver
class comparator_driver extends uvm_driver #(comparator_trans);
    virtual comparator_if vif;

    `uvm_component_utils(comparator_driver)

    function new (string name, uvm_component parent);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual comparator_if)::get(this,"","vif",vif))
            `uvm_fatal("DRV","No virtual interface bound")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            comparator_trans tr;
            seq_item_port.get_next_item(tr);

            vif.a <= tr.a;
            vif.b <= tr.b;

            #1;

            tr.A_eq_B = vif.A_eq_B;
            tr.A_gt_B = vif.A_gt_B;
            tr.A_lt_B = vif.A_lt_B;

            seq_item_port.item_done();
        end
    endtask
endclass

// 3. Monitor
class comparator_monitor extends uvm_monitor;
    virtual comparator_if vif;
    uvm_analysis_port #(comparator_trans) ap;

    `uvm_component_utils(comparator_monitor)

    function new (string name, uvm_component parent);
        super.new(name,parent);
        ap = new("ap",this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual comparator_if)::get(this,"","vif",vif))
            `uvm_fatal("MON","No virtual interface bound")
    endfunction
    
    task run_phase(uvm_phase phase);
    comparator_trans tr = comparator_trans::type_id::create("tr",this);
        forever begin
            #1;
            
            tr.a = vif.a;
            tr.b = vif.b;
            tr.A_eq_B = vif.A_eq_B;
            tr.A_gt_B = vif.A_gt_B;
            tr.A_lt_B = vif.A_lt_B;

            ap.write(tr);

            `uvm_info("MONITOR",$sformatf("a=%0d, b=%0d, A_eq_B=%0d, A_gt_B=%0d, A_lt_B=%0d", vif.a, vif.b, vif.A_eq_B, vif.A_gt_B, vif.A_lt_B),UVM_LOW)
        end
    endtask
endclass

// 4. Sequence
class comparator_sequence extends uvm_sequence #(comparator_trans);
    `uvm_object_utils(comparator_sequence)

    function new (string name="comparator_sequence");
        super.new(name);
    endfunction

    task body();
        repeat(5) begin
            comparator_trans tr = comparator_trans::type_id::create("tr");
            assert(tr.randomize());
            start_item(tr);
            finish_item(tr);
        end
    endtask
endclass

// 5. Agent
class comparator_agent extends uvm_agent;
    comparator_driver drv;
    comparator_monitor mon;
    uvm_sequencer #(comparator_trans) seqr;

    `uvm_component_utils(comparator_agent)

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        drv = comparator_driver::type_id::create("drv",this);
        mon = comparator_monitor::type_id::create("mon",this);
        seqr= uvm_sequencer #(comparator_trans)::type_id::create("seqr",this);
    endfunction

    function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass

//6. Scoreboard
class comparator_scoreboard extends uvm_component;
    uvm_analysis_imp #(comparator_trans, comparator_scoreboard) ap;

    `uvm_component_utils(comparator_scoreboard)

    function new (string name, uvm_component parent);
        super.new(name,parent);
        ap = new("ap",this);
    endfunction

    function void write(comparator_trans tr);
        // Tinh expected
        bit gt = (tr.a>tr.b);
        bit eq = (tr.a == tr.b);
        bit lt = (tr.a < tr.b);
        if (tr.A_gt_B !== gt || tr.A_eq_B !== eq || tr.A_lt_B !== lt) begin
            `uvm_error("SCOREBOARD", $sformatf("Mismatch! a=%0d b=%0d | Expected: gt=%0d eq=%0d lt=%0d | Got: gt=%0d eq=%0d lt=%0d",
                tr.a, tr.b, gt, eq, lt, tr.A_gt_B, tr.A_eq_B, tr.A_lt_B))
        end else begin
            `uvm_info("SCOREBOARD", "Comparison passed!", UVM_LOW)
        end
    endfunction

endclass

// 6. Environment
class comparator_env extends uvm_env;
    comparator_agent agent;
    comparator_scoreboard sb;

    `uvm_component_utils(comparator_env)

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = comparator_agent::type_id::create("agent",this);
        sb    = comparator_scoreboard::type_id::create("sb",this);
    endfunction

    function void connect_phase (uvm_phase phase);
        agent.mon.ap.connect(sb.ap);
    endfunction 
endclass

//7. Test
class comparator_test extends uvm_test;
    comparator_env env;
    comparator_sequence seq;

    `uvm_component_utils(comparator_test)

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        env = comparator_env::type_id::create("env",this);
        seq = comparator_sequence::type_id::create("seq",this);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass

//8. interface
interface comparator_if;
    logic[1:0] a,b;
    logic A_lt_B,A_eq_B,A_gt_B;
endinterface

// 9. Top module
module tb;
    comparator_if vif();

    comparator_2bit dut(
        .A(vif.a),
        .B(vif.b),
        .A_gt_B(vif.A_gt_B),
        .A_lt_B(vif.A_lt_B),
        .A_eq_B(vif.A_eq_B)
    );


    initial begin
        uvm_config_db#(virtual comparator_if)::set(null,"*","vif",vif);
        run_test("comparator_test");
    end
endmodule