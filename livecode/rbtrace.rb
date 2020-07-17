# For demo at 2020-07-17
require 'rbbcc'
include RbBCC

pid = ARGV[0] || begin
  puts("USAGE: #{$0} PID")
  exit 1
end

bpf_text = <<BPF
#include <uapi/linux/ptrace.h>
#include <linux/sched.h>

struct key_t {
    char c[80];
};
BPF_HISTOGRAM(dist, struct key_t);

int do_trace_create_object(struct pt_regs *ctx){
    struct key_t key = {};
    u64 zero = 0, *val;
    char klass[64];
    bpf_usdt_readarg_p(1, ctx, &key.c, sizeof(key.c));

    val = dist.lookup_or_try_init(&key, &zero);
    if (val) {
      dist.increment(key);
    }
    return 0;
}
BPF

u = USDT.new(pid: pid.to_i)
u.enable_probe(probe: "object__create", fn_name: "do_trace_create_object")

b = BCC.new(text: bpf_text, usdt_contexts: [u])

print("Tracing...")
loop do
  begin
    sleep 1
  rescue Interrupt
    puts
    break
  end
end

puts("%10s %s" % ["COUNT", "KLASS"])
counts = b.get_table("dist")
counts.items.sort_by{|k, v| v.to_bcc_value }.each do |k, v|
  puts("%10d %s" % [v.to_bcc_value, k[0, k.size].unpack("Z*")[0]])
end
