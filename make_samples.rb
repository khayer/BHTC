#!/usr/bin/env ruby
require "yaml"
#require "rubygems"
require 'erubis'
require "optparse"
require "logger"

options = {:email => "katharinaehayer@gmail.com",
           :tissue => nil,
           :ct => nil,
           :output_dir => nil
          }

# OptionParser
OptionParser.new do |opts|
  opts.banner = "Usage: make_bwa_runs [options]"

  opts.on("-t", "--tissue TISSUE", :REQUIRED, String, "Tissue") do |i|
    options[:tissue] = i
  end

  opts.on("-o", "--output_dir DIR", :REQUIRED, String, "Directory for the results.") do |i|
    options[:output_dir] = i
  end

  opts.on("-e", "--e_mail EMAIL", String, "E-mail address. (default: katharinaehayer@gmail.com)") do |i|
    options[:email] = i
  end

  opts.on("-c","--ct INT", String, "Specific time point(s), comma seperated (default 22,26,...)") do |i|
    options[:ct] =  i.split(",").map {|e| e.to_i}
  end

  opts.on_tail("-h", "--help", "Show this message") do
    STDERR.puts opts
    exit
  end
end.parse!

def usage
  "ruby #{$0} -t tissue -o result_dir [-c ct]"
end

unless options[:tissue] && options[:output_dir]
  STDERR.puts usage
  exit
end
log = Logger.new(STDERR)
options[:ct] = [22,28,34,40,46,52,58,64] unless options[:ct]
log.info("CURRENT OPTIONS:")
log.info(options.to_yaml)

qsub_template =<<EOF
#!/bin/bash
#\$ -V
#\$ -cwd
#\$ -j y
#\$ -l h_vmem=7.4G
#\$ -pe orte 4
#\$ -m ae
#\$ -M <%= @email %>
#\$ -N <%= @tissue %>_CT<%= @ct %>

cp /data/BHTC/<%= @tissue %>_CT<%= @ct %>_*R1.fastq.gz /mnt/ &
cp /data/BHTC/<%= @tissue %>_CT<%= @ct %>_*R2.fastq.gz /mnt/ &
wait
/data/tools/STAR_2.3.0e.Linux_x86_64_static/STAR --genomeDir /data/mm9/ --readFilesIn /mnt/<%= @tissue %>_CT<%= @ct %>_*R1.fastq.gz /mnt/<%= @tissue %>_CT<%= @ct %>_*R2.fastq.gz  --runMode alignReads --runThreadN 3 --readFilesCommand zcat  --sjdbGTFfile /data/mm9_refseq_ucsc_vega_gene_info.gtf --outFileNamePrefix /mnt/<%= @tissue %>_CT<%= @ct %>_
rm /mnt/<%= @tissue %>_CT<%= @ct %>_*R1.fastq.gz &
rm /mnt/<%= @tissue %>_CT<%= @ct %>_*R2.fastq.gz &
wait
mkdir -p <%= @result_dir %>
cp /mnt/<%= @tissue %>_CT<%= @ct %>_* <%= @result_dir %>
EOF

eruby = Erubis::Eruby.new(qsub_template)
runfile = File.open("#{options[:tissue]}_qsub_all.sh",'w')
options[:ct].each do |ct|

  context = {
    :result_dir => options[:output_dir],
    :email => options[:email],
    :account => options[:account],
    :ct => ct,
    :tissue => options[:tissue]
  }

  # open file to output shell script
  o = File.open("#{options[:tissue]}_CT#{ct}.sh",'w')
  o.puts(eruby.evaluate(context))
  log.info("Sent:")
  log.info(eruby.evaluate(context))
  o.close()
  runfile.puts("qsub #{options[:tissue]}_CT#{ct}.sh")
end
