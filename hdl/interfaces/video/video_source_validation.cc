// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "video_source_validation.h"

#include <bitset>
#include <cassert>
#include <fstream>
#include <iostream>

constexpr std::optional<uint> VideoSourceValidation::try_decode_as_control(uint c)
{
  switch (c)
  {
  case 0b1101010100:
    return 0b00;
  case 0b0010101011:
    return 0b01;
  case 0b0101010100:
    return 0b10;
  case 0b1010101011:
    return 0b11;
  default:
    return {};
  }
}

constexpr std::optional<uint> VideoSourceValidation::try_decode_as_terc4(uint c)
{
  switch (c)
  {
  case 0b1010011100:
    return 0b0000;
  case 0b1001100011:
    return 0b0001;
  case 0b1011100100:
    return 0b0010;
  case 0b1011100010:
    return 0b0011;
  case 0b0101110001:
    return 0b0100;
  case 0b0100011110:
    return 0b0101;
  case 0b0110001110:
    return 0b0110;
  case 0b0100111100:
    return 0b0111;
  case 0b1011001100:
    return 0b1000;
  case 0b0100111001:
    return 0b1001;
  case 0b0110011100:
    return 0b1010;
  case 0b1011000110:
    return 0b1011;
  case 0b1010001110:
    return 0b1100;
  case 0b1001110001:
    return 0b1101;
  case 0b0101100011:
    return 0b1110;
  case 0b1011000011:
    return 0b1111;
  default:
    return {};
  }
}

uint VideoSourceValidation::decode_data(uint c)
{
  assert(c < 0x400);

  // if D[9], invert D[7:0]
  if ((c & 0x200) == 0x200)
  {
    // Mask after inversion to avoid a ones compliment negative number.
    c = (c & 0x300) | (~(c & 0xff) & 0xff);
  }

  auto d = std::bitset<8>{c & 0xff};
  auto q = std::bitset<8>{};

  // Compute XOR/XNOR values depending if D[8].
  if ((c & 0x100) == 0x100)
  {
    // XOR
    q[0] = d[0];
    q[1] = d[1] ^ d[0];
    q[2] = d[2] ^ d[1];
    q[3] = d[3] ^ d[2];
    q[4] = d[4] ^ d[3];
    q[5] = d[5] ^ d[4];
    q[6] = d[6] ^ d[5];
    q[7] = d[7] ^ d[6];
  }
  else
  {
    // XNOR
    q[0] = d[0];
    q[1] = !(d[1] ^ d[0]);
    q[2] = !(d[2] ^ d[1]);
    q[3] = !(d[3] ^ d[2]);
    q[4] = !(d[4] ^ d[3]);
    q[5] = !(d[5] ^ d[4]);
    q[6] = !(d[6] ^ d[5]);
    q[7] = !(d[7] ^ d[6]);
  }

  return q.to_ulong();
}

constexpr bool VideoSourceValidation::is_video_preamble(uint ch0, uint ch1, uint ch2)
{
  // ch0 is ignored since it encodes h_sync/v_sync.
  (void)ch0;

  return ch1 == 0b01 && ch2 == 0b00;
}

constexpr bool VideoSourceValidation::is_video_guard_band(uint ch0, uint ch1, uint ch2)
{
  return ch0 == 0b1011001100 && ch1 == 0b0100110011 && ch2 == 0b1011001100;
}

void VideoSourceValidation::validate_characters(uint ch0, uint ch1, uint ch2)
{
  auto ch0_ctl = try_decode_as_control(ch0);
  auto ch1_ctl = try_decode_as_control(ch1);
  auto ch2_ctl = try_decode_as_control(ch2);

  // Assert characters are aligned.
  assert((ch0_ctl.has_value() && ch1_ctl.has_value() && ch2_ctl.has_value()) ||
         !(ch0_ctl.has_value() || ch1_ctl.has_value() || ch2_ctl.has_value()));

  if (ch0_ctl.has_value())
  {
    // Test control period parameters.
    video_data_period = false;
    control_period = true;
    ++control_period_dots;

    if (is_video_preamble(*ch0_ctl, *ch1_ctl, *ch2_ctl))
    {
      if (!video_preamble)
      {
        assert(preamble_dots == 0);

        if (control_period_dots < 4)
        {
          std::cout << "Preamble spacing violation. Current control period "
                    << control_period_dots << " dots." << std::endl;
        }

        video_preamble = true;
        ++preamble_dots;
      }
      else
      {
        ++preamble_dots;

        if (preamble_dots > 8)
        {
          std::cout << "Preamble too long, "
                    << preamble_dots << " dots." << std::endl;
        }
      }
    }

    auto h_sync = (*ch0_ctl & 0x1) != 0;
    auto v_sync = (*ch0_ctl & 0x2) != 0;

    if (!previous_h_sync && h_sync)
    {
      if (!previous_v_sync && v_sync)
      {
        ++frames;
        v_active_lines = 0;
      }

      if (previous_h_active_dots == 0 || h_active_dots != 0)
      {
        previous_h_active_dots = h_active_dots;
      }

      previous_v_sync = v_sync;
      h_active_dots = 0;
    }

    previous_h_sync = h_sync;
  }
  else if (is_video_guard_band(ch0, ch1, ch2))
  {
    if (!video_guard_band)
    {
      assert(control_period_dots > preamble_dots);
      assert(guard_band_dots == 0);

      if (preamble_dots != 8)
      {
        std::cout << "Preamble incorrect length, " << preamble_dots << " dots." << std::endl;
      }

      video_preamble = false;
      control_period_dots = 0;
      preamble_dots = 0;

      video_guard_band = true;
      video_data_period = true;

      ++guard_band_dots;
      ++v_active_lines;
    }
    else
    {
      ++guard_band_dots;

      if (guard_band_dots > 2)
      {
        std::cout << "Video guard band too long, "
                  << guard_band_dots << " dots." << std::endl;
      }
    }
  }
  else
  {
    assert(video_data_period);

    if (video_guard_band)
    {
      assert(h_active_dots == 0);

      if (guard_band_dots != 2)
      {
        std::cout << "Video guard band incorrect length, "
                  << guard_band_dots << " dots." << std::endl;
      }

      video_guard_band = false;
      guard_band_dots = 0;
    }

    ++h_active_dots;

    buffer.push_back(
        Pixel{.r = static_cast<char>(decode_data(ch2)),
              .g = static_cast<char>(decode_data(ch1)),
              .b = static_cast<char>(decode_data(ch0))});
  }
}

void VideoSourceValidation::save_frame_buffer(std::string &file_path, uint h_active, uint v_active)
{
  using namespace std;

  if (buffer.size() == 0)
  {
    std::cout << "No pixel data for frame " << frames << std::endl;
    return;
  }

  assert(buffer.size() == h_active * v_active);

  cout << "Frame " << frames << " " << h_active << "x" << v_active << endl;

  auto f = ofstream(file_path, ios_base::out | ios_base::binary);
  f << "P6" << endl
    << h_active << ' ' << v_active << endl
    << "255" << endl;

  for (auto i = 0u; i < buffer.size(); ++i)
  {
    f << buffer[i].r << buffer[i].g << buffer[i].b;
  }

  f.close();
}
