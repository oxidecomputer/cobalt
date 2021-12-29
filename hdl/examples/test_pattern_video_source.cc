// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <bitset>
#include <cassert>
#include <fstream>
#include <iostream>
#include <sstream>

#include <backends/cxxrtl/cxxrtl_vcd.h>

#include "hdl/examples/mk100pTestPatternVideoSource.h"
#include "hdl/interfaces/video/video_source_validation.h"


struct Source : private cxxrtl_design::p_mk100pTestPatternVideoSource
{
public:
  void init_debug(uint timescale_number, const std::string &timescale_unit)
  {
    debug_info(debug_items_);
    vcd_.timescale(timescale_number, timescale_unit);
    vcd_.add_without_memories(debug_items_);
    write_debug_ = true;
  }

  void write_debug_waves(std::ostream& f)
  {
    if (!write_debug_)
    {
      return;
    }

    f << vcd_.buffer;
    vcd_.buffer.clear();
  }

  void reset()
  {
    p_CLK.set(false);
    p_RST__N.set(false);
    step();

    if (write_debug_)
    {
      vcd_.sample(steps_++);
    }

    tick();
    tick();
    p_RST__N.set(true);
  }

  void tick()
  {
    p_EN__characters__get.set(ch_valid());
    p_CLK.set(!p_CLK.get<bool>());
    step();

    if (write_debug_)
    {
      vcd_.sample(steps_++);
    }
  }

  void cycle()
  {
    tick();
    tick();
  }

  // Return the value of the given channel.
  template <size_t N>
  uint ch()
  {
    return static_cast<uint>(p_characters__get.get<uint64_t>() >> (N * 10)) & 0x3ff;
  }

  bool h_sync_ref()
  {
    return p_h__sync.get<bool>();
  }

  bool v_sync_ref()
  {
    return p_v__sync.get<bool>();
  }

  bool ch_valid()
  {
    return p_RDY__characters__get.get<bool>();
  }

  constexpr uint frames()
  {
    return validate_.frames;
  }

  void validate_characters()
  {
    validate_.validate_characters(ch<0>(), ch<1>(), ch<2>());
  }

  void save_frame_buffer(std::string& file_path)
  {
    validate_.save_frame_buffer(
      file_path,
      validate_.previous_h_active_dots,
      validate_.v_active_lines);
    validate_.buffer.clear();
  }

private:
  bool write_debug_{false};
  uint steps_{0};

  cxxrtl::debug_items debug_items_{};
  cxxrtl::vcd_writer vcd_{};

  VideoSourceValidation validate_{};
};

int main()
{
  auto src = Source{};
  auto vcd = std::ofstream("test_pattern_video_source.vcd");

  src.init_debug(1, "us"); // Load signal information for debug.

  src.reset();
  src.write_debug_waves(vcd);

  // Set timing and test pattern parameters (implicit during this cycle).
  src.cycle();
  src.write_debug_waves(vcd);

  // The TMDS encoding pipeline takes several cycles to produce valid characters, skip to the first
  // valid characters.
  while (!src.ch_valid())
  {
    src.cycle();
    src.write_debug_waves(vcd);
  }

  auto frames = 0;
  for (auto cycles = 0; frames < 2; ++cycles)
  {
    src.tick();
    assert(src.ch_valid());

    src.validate_characters();

    if (src.v_sync_ref())
    {
      if (src.frames() > 0)
      {
        auto file_name_os = std::ostringstream{};
        file_name_os << "frame" << src.frames() << ".ppm";

        auto file_name = file_name_os.str();
        src.save_frame_buffer(file_name);
      }

      ++frames;
    }

    src.tick();
    src.write_debug_waves(vcd);
  }

  std::cout << "Done" << std::endl;
  return 0;
}
